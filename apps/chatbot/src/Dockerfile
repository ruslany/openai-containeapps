FROM python:3.11-slim

WORKDIR /srv
ADD ./requirements.txt /srv/requirements.txt
RUN pip install -r /srv/requirements.txt
ADD . /srv

EXPOSE 8501

ENTRYPOINT ["streamlit", "run", "chat.py", "--server.port=8501"]