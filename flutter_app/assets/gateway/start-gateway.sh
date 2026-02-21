#!/bin/bash
# Unified AI Gateway Startup Script for Android
# This script starts the unified gateway inside proot Ubuntu

set -e

GATEWAY_DIR="/root/.unified-gateway"
ASSETS_DIR="/data/data/com.sadadonline17.cloudai_gateway/files/gateway"
LOG_FILE="$GATEWAY_DIR/gateway.log"
PID_FILE="$GATEWAY_DIR/gateway.pid"

# Create gateway directory
mkdir -p "$GATEWAY_DIR"

# Copy gateway files from assets if not exists
if [ ! -f "$GATEWAY_DIR/lib/index.js" ]; then
    echo "Copying gateway files from assets..."
    cp -r "$ASSETS_DIR"/* "$GATEWAY_DIR/"
fi

# Install dependencies if node_modules not exists
if [ ! -d "$GATEWAY_DIR/node_modules" ]; then
    echo "Installing Node.js dependencies..."
    cd "$GATEWAY_DIR"
    npm install --production
fi

# Set NODE_OPTIONS for bionic bypass
export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js"

# Start the gateway
echo "Starting Unified AI Gateway..."
cd "$GATEWAY_DIR"
node lib/index.js > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "Gateway started with PID: $(cat $PID_FILE)"
echo "HTTP: http://localhost:18789"
echo "WebSocket: ws://localhost:18790"
