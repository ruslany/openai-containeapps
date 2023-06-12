FROM python:3.10.0-slim

WORKDIR /srv
ADD ./requirements.txt /srv/requirements.txt
RUN pip install -r requirements.txt
ADD . /srv

EXPOSE 8501

ENTRYPOINT ["streamlit", "run", "chat.py", "--server.port=8501"]