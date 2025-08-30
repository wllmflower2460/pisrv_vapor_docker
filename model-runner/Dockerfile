FROM python:3.11-slim
ENV OMP_NUM_THREADS=2
RUN pip install --no-cache-dir fastapi uvicorn torch==2.2.2 numpy
WORKDIR /app
COPY main.py /app/
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]