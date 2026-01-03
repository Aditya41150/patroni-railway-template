FROM haproxy:2.9-alpine

# Install curl for health checks
RUN apk add --no-cache curl gettext

# Copy HAProxy configuration template
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg.template
COPY start-haproxy.sh /start-haproxy.sh

# Make startup script executable
RUN chmod +x /start-haproxy.sh

# Expose ports
# 5432: PostgreSQL write port (primary)
# 5433: PostgreSQL read port (replicas)
# 7000: Stats UI
# 8008: Health check endpoint
EXPOSE 5432 5433 7000 8008

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8008/health || exit 1

ENTRYPOINT ["/start-haproxy.sh"]
