FROM golang:1.22-bullseye

LABEL maintainer="yourname@example.com"
LABEL description="Comprehensive JS Recon Tool with Subdomain Enumeration"

ENV PATH="/root/go/bin:$PATH"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
        python3 python3-pip \
        git curl wget \
        build-essential jq \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Go-based tools
RUN go install github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install github.com/projectdiscovery/gauplus/cmd/gauplus@latest && \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install github.com/tomnomnom/assetfinder@latest && \
    go install github.com/tomnomnom/waybackurls@latest

# Install Python dependencies
RUN pip3 install requests

# Add working directory
WORKDIR /app

# Copy script
COPY jsrecon.py /app/jsrecon.py

ENTRYPOINT ["python3", "jsrecon.py"]
