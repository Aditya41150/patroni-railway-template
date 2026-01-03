FROM postgres:16-alpine

# Install required packages
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2 \
    curl \
    bash \
    && pip3 install --no-cache-dir --break-system-packages \
    patroni[etcd]==3.2.1 \
    python-etcd==0.4.5

# Create necessary directories
RUN mkdir -p /var/lib/postgresql/data /etc/patroni

# Copy Patroni configuration template
COPY patroni.yml /etc/patroni/patroni.yml
COPY start-patroni.sh /start-patroni.sh

# Make startup script executable
RUN chmod +x /start-patroni.sh

# Expose PostgreSQL port
EXPOSE 5432 8008

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8008/health || exit 1

# Use custom entrypoint
ENTRYPOINT ["/start-patroni.sh"]
