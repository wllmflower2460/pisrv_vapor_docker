FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    OMP_NUM_THREADS=2 \
    PIP_NO_CACHE_DIR=1
RUN pip install --no-cache-dir fastapi uvicorn torch==2.2.2 numpy
WORKDIR /app
COPY main.py /app/
# Create non-root user
RUN groupadd -g 10001 appuser \
 && useradd -m -u 10001 -g 10001 -s /usr/sbin/nologin appuser \
 && chown -R appuser:appuser /app
USER appuser:appuser
EXPOSE 8000
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]