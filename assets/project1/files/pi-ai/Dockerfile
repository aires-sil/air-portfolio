FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for building llama-cpp-python and other packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    unzip \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --upgrade pip
RUN pip install --no-cache-dir duckduckgo-search==8.1.1
RUN pip install --no-cache-dir \
    torch \
    sentence-transformers \
    llama-cpp-python \
    requests \
    flask \
    flask-httpauth \
    python-dotenv

# Copy scripts and start
COPY scripts/ ./scripts/
COPY ai_data/ ./ai_data/
COPY models/ ./models/
COPY templates/ ./templates/
COPY static/ ./static/
COPY .env ./

# Make start script executable
RUN chmod +x ./scripts/start_all.sh

# Run your script
CMD ["./scripts/start_all.sh"]
