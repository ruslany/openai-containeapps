from typing import Iterator
from numpy import array, average
import openai
import pandas as pd
import numpy as np
from tenacity import retry, wait_random_exponential, stop_after_attempt
import tiktoken
from typing import List, Iterator
import concurrent

from tqdm import tqdm

from config import TEXT_EMBEDDING_CHUNK_SIZE, EMBEDDINGS_MODEL

from config import AZURE_OPENAI_API_KEY, AZURE_OPENAI_BASE_URL, AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME

from database import load_vectors

def get_col_average_from_list_of_lists(list_of_lists):
    """Return the average of each column in a list of lists."""
    if len(list_of_lists) == 1:
        return list_of_lists[0]
    else:
        list_of_lists_array = array(list_of_lists)
        average_embedding = average(list_of_lists_array, axis=0)
        return average_embedding.tolist()

# Create embeddings for a text using a tokenizer and an OpenAI engine

def create_embeddings_for_text(text, tokenizer):
    """Return a list of tuples (text_chunk, embedding) and an average embedding for a text."""
    token_chunks = list(chunks(text, TEXT_EMBEDDING_CHUNK_SIZE, tokenizer))
    text_chunks = [tokenizer.decode(chunk) for chunk in token_chunks]

    #embeddings_response = get_embeddings(text_chunks, EMBEDDINGS_MODEL)
    embeddings = embed_corpus(text_chunks, 1)
    #embeddings = [embedding["embedding"] for embedding in embeddings_response]
    #embeddings = [embedding["embedding"] for embedding in embeddings]
    text_embeddings = list(zip(text_chunks, embeddings))

    average_embedding = get_col_average_from_list_of_lists(embeddings)

    return (text_embeddings, average_embedding)

def get_embeddings(text_array, engine):
    response = openai.Embedding.create(deployment_id = AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME,
        input=text_array,
        model=engine,
    )["data"]
    
    return response
    
    #return [data["embedding"] for data in response]
    #return openai.Engine(id=engine).embeddings(input=text_array)["data"]

## Batch Embedding Logic

# Simple function to take in a list of text objects and return them as a list of embeddings
@retry(wait=wait_random_exponential(min=1, max=40), stop=stop_after_attempt(10))
def get_embeddings(input: List):
    response = openai.Embedding.create(deployment_id = "text-embedding-ada-002",
        input=input,
        model=EMBEDDINGS_MODEL,
    )["data"]
    return [data["embedding"] for data in response]

def batchify(iterable, n=1):
    l = len(iterable)
    for ndx in range(0, l, n):
        yield iterable[ndx : min(ndx + n, l)]

# Function for batching and parallel processing the embeddings
def embed_corpus(
    corpus: List[str],
    batch_size=1,
    num_workers=8,
    max_context_len=8191,
):

    # Encode the corpus, truncating to max_context_len
    encoding = tiktoken.get_encoding("cl100k_base")
    encoded_corpus = [
        encoded_article[:max_context_len] for encoded_article in encoding.encode_batch(corpus)
    ]

    # Calculate corpus statistics: the number of inputs, the total number of tokens, and the estimated cost to embed
    num_tokens = sum(len(article) for article in encoded_corpus)
    cost_to_embed_tokens = num_tokens / 1_000 * 0.0004
    print(
        f"num_articles={len(encoded_corpus)}, num_tokens={num_tokens}, est_embedding_cost={cost_to_embed_tokens:.2f} USD"
    )

    # Embed the corpus
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_workers) as executor:
        
        futures = [
            executor.submit(get_embeddings, text_batch)
            for text_batch in batchify(encoded_corpus, batch_size)
        ]

        with tqdm(total=len(encoded_corpus)) as pbar:
            for _ in concurrent.futures.as_completed(futures):
                pbar.update(batch_size)

        embeddings = []
        for future in futures:
            data = future.result()
            embeddings.extend(data)

        return embeddings



# Split a text into smaller chunks of size n, preferably ending at the end of a sentence
def chunks(text, n, tokenizer):
    """Yield successive n-sized chunks from text."""
    tokens = tokenizer.encode(text)
    i = 0
    while i < len(tokens):
        # Find the nearest end of sentence within a range of 0.5 * n and 1.5 * n tokens
        j = min(i + int(1.5 * n), len(tokens))
        while j > i + int(0.5 * n):
            # Decode the tokens and check for full stop or newline
            chunk = tokenizer.decode(tokens[i:j])
            if chunk.endswith(".") or chunk.endswith("\n"):
                break
            j -= 1
        # If no end of sentence found, use n tokens as the chunk size
        if j == i + int(0.5 * n):
            j = min(i + n, len(tokens))
        yield tokens[i:j]
        i = j
        
def get_unique_id_for_file_chunk(filename, chunk_index):
    return str(filename+"-!"+str(chunk_index))

def handle_file_string(file, tokenizer, redis_conn, text_embedding_field, index_name):
    """
    Handle a file string by cleaning it up, creating embeddings, and uploading them to Redis.

    Args:
        file (tuple): A tuple containing the filename and file body string.
        tokenizer: The tokenizer object to use for encoding and decoding text.
        redis_conn: The Redis connection object.
        text_embedding_field (str): The field in Redis where the text embeddings will be stored.
        index_name: The name of the index or identifier for the embeddings.

    Returns:
        None

    Raises:
        Exception: If there is an error creating embeddings or uploading to Redis.

    """
    filename = file[0]
    file_body_string = file[1]

    # Clean up the file string by replacing newlines, double spaces, and semi-colons
    clean_file_body_string = file_body_string.replace("  ", " ").replace("\n", "; ").replace(';', ' ')
    
    # Add the filename to the text to embed
    text_to_embed = "Filename is: {}; {}".format(filename, clean_file_body_string)

    try:
        # Create embeddings for the text
        text_embeddings, average_embedding = create_embeddings_for_text(text_to_embed, tokenizer)
        # print("[handle_file_string] Created embedding for {}".format(filename))
    except Exception as e:
        print("[handle_file_string] Error creating embedding: {}".format(e))

    # Get the vectors array of triples: file_chunk_id, embedding, metadata for each embedding
    # Metadata is a dict with keys: filename, file_chunk_index
    vectors = []
    for i, (text_chunk, embedding) in enumerate(text_embeddings):
        id = get_unique_id_for_file_chunk(filename, i)
        vectors.append({'id': id, "vector": embedding, 'metadata': {"filename": filename,
                                                                    "text_chunk": text_chunk,
                                                                    "file_chunk_index": i}})

    try:
        # Load vectors into Redis
        load_vectors(redis_conn, vectors, text_embedding_field)
    except Exception as e:
        print(f'Ran into a problem uploading to Redis: {e}')


# Make a class to generate batches for insertion
class BatchGenerator:
    
    
    def __init__(self, batch_size: int = 10) -> None:
        self.batch_size = batch_size
    
    # Makes chunks out of an input DataFrame
    def to_batches(self, df: pd.DataFrame) -> Iterator[pd.DataFrame]:
        splits = self.splits_num(df.shape[0])
        if splits <= 1:
            yield df
        else:
            for chunk in np.array_split(df, splits):
                yield chunk

    # Determines how many chunks DataFrame contains
    def splits_num(self, elements: int) -> int:
        return round(elements / self.batch_size)
    
    __call__ = to_batches
