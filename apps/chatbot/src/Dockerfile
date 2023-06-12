FROM python:3.11-slim

WORKDIR /srv
ADD ./apps/chatbot/src/Dockerfile /srv/requirements.txt
RUN pip install -r requirements.txt
ADD ./apps/chatbot/src /srv

EXPOSE 8501

ENTRYPOINT ["streamlit", "run", "chat.py", "--server.port=8501"]