FROM python:3.11-slim

# Install system tools useful for the lab (curl, jq) and Docker CLI
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

# Intentionally insecure: credentials stored in a plaintext config file
RUN echo "# AzureAssist Internal Configuration" > /opt/db_config.txt && \
    echo "DB_URL=mongodb://admin:S3cur3P4ss!2026@db.internal:27017/prod" >> /opt/db_config.txt && \
    echo "KEY_VAULT_URI=https://kv-stags-lab.vault.azure.net/" >> /opt/db_config.txt && \
    echo "BACKUP_KEY=bk-9f2a3c1e4d8b7a6f" >> /opt/db_config.txt

# Flag 2 only accessible after container escape (on the host filesystem)
# Represented here by a file that hints students toward the host path
RUN echo "Check /host_flag/FLAG_2.txt after escaping the container" > /tmp/next_step.txt

WORKDIR /app
CMD ["python", "app/main.py"]
