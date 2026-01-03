FROM quay.io/coreos/etcd:v3.5.11

# Create data directory
RUN mkdir -p /etcd-data

# Set working directory
WORKDIR /etcd-data

# Expose etcd ports
# 2379: Client communication
# 2380: Peer communication
EXPOSE 2379 2380

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
  CMD etcdctl endpoint health --endpoints=http://localhost:2379 || exit 1

# Entry point will be overridden by Railway start command
ENTRYPOINT ["/usr/local/bin/etcd"]
