FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install -y curl jq coreutils && \
    rm -rf /var/lib/apt/lists/*

COPY generate_logs.sh /generate_logs.sh
RUN chmod +x /generate_logs.sh

CMD ["/generate_logs.sh"]

