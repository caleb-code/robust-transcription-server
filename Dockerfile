# syntax=docker/dockerfile:1.5  # Enables BuildKit features
FROM nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04 AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off

# ------------------------
# Stage 1: Install system deps and Python
# ------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
        build-essential \
        libpcre3 libpcre3-dev \
        zlib1g zlib1g-dev \
        libssl-dev \
        wget \
        unzip \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /

# ------------------------
# Stage 2: Install Python dependencies
# ------------------------
# Copy only requirements.txt first to leverage cache
COPY requirements.txt .

RUN pip install --break-system-packages -r requirements.txt

# Pre-download faster_whisper model
RUN python3 -c "from faster_whisper import download_model; download_model('turbo')"

# ------------------------
# Stage 3: Copy application code
# ------------------------
COPY . .

# ------------------------
# Stage 4: Compile Nginx with RTMP module
# ------------------------
RUN wget http://nginx.org/download/nginx-1.28.0.tar.gz \
    && tar -xzf nginx-1.28.0.tar.gz \
    && wget https://github.com/arut/nginx-rtmp-module/archive/refs/heads/master.zip \
    && unzip master.zip \
    && cd nginx-1.28.0 \
    && ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module-master \
    && make -j$(nproc) \
    && make install \
    && cd /

# Copy custom nginx configuration
COPY nginx.conf /usr/local/nginx/conf/nginx.conf

# Expose RTMP port
EXPOSE 1935

# ------------------------
# Stage 6: Entry point
# ------------------------
# start bash
CMD sh -c "/usr/local/nginx/sbin/nginx && python3 main.py"
