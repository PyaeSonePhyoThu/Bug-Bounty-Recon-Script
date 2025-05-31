FROM golang:1.22-bullseye AS builder

# Install basic tools
RUN apt-get update && apt-get install -y python3 python3-pip curl git golang-go

# Install Go tools
RUN go install github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install github.com/projectdiscovery/gauplus/cmd/gauplus@latest && \
    go install github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install github.com/tomnomnom/waybackurls@latest

# Create runtime image
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y python3 python3-pip ca-certificates && \
    apt-get clean

# Copy tools from builder
COPY --from=builder /go/bin/katana /usr/local/bin/katana
COPY --from=builder /go/bin/gauplus /usr/local/bin/gauplus
COPY --from=builder /go/bin/httpx /usr/local/bin/httpx
COPY --from=builder /go/bin/waybackurls /usr/local/bin/waybackurls

# Copy Python script
COPY jsrecon.py /app/jsrecon.py
WORKDIR /app

# Install Python dependencies
RUN pip3 install requests

# Entrypoint
ENTRYPOINT ["python3", "jsrecon.py"]
