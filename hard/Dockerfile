FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
       https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
       | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# Intentionally insecure configuration file
RUN echo "# CloudGuard AI Internal Config" > /opt/db_config.txt && \
    echo "DB_URL=mongodb://admin:H@rdP4ssw0rd2026!@db.internal:27017/prod" >> /opt/db_config.txt && \
    echo "KEY_VAULT_URI=https://kv-stags-lab.vault.azure.net/" >> /opt/db_config.txt && \
    echo "BACKUP_STORAGE_KEY=DefaultEndpointsProtocol=https;AccountName=stagslabstorage;AccountKey=abc123def456xyz789==" >> /opt/db_config.txt

WORKDIR /app
CMD ["python", "app/main.py"]
