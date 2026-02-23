FROM --platform=arm64 ubuntu:latest 
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*
RUN curl -O https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_arm64.zip \
    && unzip terraform_1.7.0_linux_arm64.zip -d /usr/local/bin/ \       
    && rm terraform_1.7.0_linux_arm64.zip
WORKDIR /app
COPY . .
CMD ["terraform", "init"]
