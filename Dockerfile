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


# Install s3fs to mount S3 bucket
RUN apt update && apt install -y s3fs
RUN echo "*******REMOVED*******:*******REMOVED*******" > /passwd_file
RUN chmod 600 /passwd_file
RUN mkdir /configs
# Mount the S3 bucket (replace 'your-bucket-name' with your actual bucket name
RUN s3fs configs-transcription /configs -o passwd_file=/passwd_file

# Expose the RTMP port
EXPOSE 1935

# Start the Python application and Nginx server
CMD ["sh", "-c", "/usr/local/nginx/sbin/nginx && python main.py"]