#!/bin/bash

# Quick Start Script for Local Testing
# This script helps you quickly spin up the Patroni HA cluster locally

set -e

echo "================================================"
echo "Patroni PostgreSQL HA Cluster - Quick Start"
echo "================================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

echo "Starting Patroni HA cluster..."
echo ""

# Start services
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start..."
echo "   This may take 2-3 minutes..."
echo ""

# Wait for etcd cluster
echo "Waiting for etcd cluster..."
for i in {1..30}; do
    if docker-compose exec -T etcd1 etcdctl endpoint health --endpoints=http://localhost:2379 &> /dev/null; then
        echo "✅ etcd cluster is ready"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Wait for Patroni cluster
echo "Waiting for Patroni cluster..."
sleep 30
for i in {1..30}; do
    if docker-compose exec -T patroni1 curl -s http://localhost:8008/health &> /dev/null; then
        echo "✅ Patroni cluster is ready"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Wait for HAProxy
echo "Waiting for HAProxy..."
for i in {1..20}; do
    if curl -s http://localhost:8008/health &> /dev/null; then
        echo "✅ HAProxy is ready"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

echo "================================================"
echo "✅ Cluster is ready!"
echo "================================================"
echo ""

# Show cluster status
echo "Cluster Status:"
docker-compose exec -T patroni1 patronictl -c /tmp/patroni.yml list || echo "Note: Cluster may still be initializing..."
echo ""

echo "Connection Information:"
echo "  Write (Primary):  postgresql://postgres:testpassword123@localhost:5432/postgres"
echo "  Read (Replicas):  postgresql://postgres:testpassword123@localhost:5433/postgres"
echo ""

echo "HAProxy Stats Dashboard:"
echo "  URL: http://localhost:7000/stats"
echo "  Username: admin"
echo "  Password: admin123"
echo ""

echo "Useful Commands:"
echo "  View logs:           docker-compose logs -f"
echo "  Check status:        docker-compose ps"
echo "  Stop cluster:        docker-compose down"
echo "  Remove all data:     docker-compose down -v"
echo ""

echo "Test Connection:"
echo "  psql \"postgresql://postgres:testpassword123@localhost:5432/postgres\" -c \"SELECT version();\""
echo ""
