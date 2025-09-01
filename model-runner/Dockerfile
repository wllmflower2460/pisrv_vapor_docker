FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OMP_NUM_THREADS=2

RUN pip install --no-cache-dir fastapi uvicorn torch==2.2.2 numpy

WORKDIR /app
COPY main.py /app/

EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]