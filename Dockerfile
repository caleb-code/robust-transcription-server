FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-venv \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN apt update
RUN apt install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev wget

RUN python3 -m pip install --upgrade pip

WORKDIR /

COPY . .

RUN pip install -r requirements.txt

RUN python -c "from faster_whisper import download_model; download_model('large-v3')"

# Install FFmpeg
RUN apt install -y ffmpeg

# Download and extract Nginx
RUN wget http://nginx.org/download/nginx-1.28.0.tar.gz
RUN tar -xzvf nginx-1.28.0.tar.gz
RUN cd nginx-1.28.0

# Download the nginx-rtmp-module
RUN wget https://github.com/arut/nginx-rtmp-module/archive/refs/heads/master.zip
RUN apt install -y unzip
RUN unzip master.zip

# Compile and install Nginx with the RTMP module
RUN cd nginx-1.28.0 && ./configure --with-http_ssl_module --add-module=../nginx-rtmp-module-master && make && make install

COPY nginx.conf /usr/local/nginx/conf/nginx.conf

# Set cuDNN version for CUDA 12.9
ENV CUDNN_VERSION=9.3.2.105

# Download cuDNN for Linux x86_64 CUDA 12.9
RUN wget https://developer.download.nvidia.com/compute/redist/cudnn/v9.3.2/cudnn-local-repo-ubuntu2404-9.3.2.105_1.0-1_amd64.deb \
    && dpkg -i cudnn-local-repo-ubuntu2404-9.3.2.105_1.0-1_amd64.deb \
    && apt-key add /var/cudnn-local-repo-*/7fa2af80.pub \
    && apt-get update \
    && apt-get install -y --no-install-recommends libcudnn9 libcudnn9-dev \
    && rm -rf /var/lib/apt/lists/* cudnn-local-repo-ubuntu2404-9.3.2.105_1.0-1_amd64.deb

# Install s3fs to mount S3 bucket
RUN apt update
RUN apt install s3fs
RUN echo "*******REMOVED*******:*******REMOVED*******" > /passwd_file
RUN chmod 600 /passwd_file
RUN s3fs configs-transcription /configs -o passwd_file=/passwd_file

# Expose the RTMP port
EXPOSE 1935

# Start the Python application and Nginx server
CMD ["sh", "-c", "/usr/local/nginx/sbin/nginx && python main.py"]