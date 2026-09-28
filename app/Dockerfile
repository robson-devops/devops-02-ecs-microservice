# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser

# psycopg[binary] traz wheel compilado: sem gcc nem libpq-dev na imagem final,
# o que reduz tamanho e superfície de ataque.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY db.py main.py ./

USER appuser

EXPOSE 8000

# Liveness, não readiness: o container não deve se declarar morto porque o
# banco oscilou. Quem decide tirar a task de rotação é o target group do ALB.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
