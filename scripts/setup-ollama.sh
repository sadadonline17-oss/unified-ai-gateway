#!/bin/bash
# Setup Ollama in proot Ubuntu environment
# Part of Unified AI Gateway for Android

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf) echo "arm" ;;
        x86_64) echo "amd64" ;;
        *) echo "unknown" ;;
    esac
}

ARCH=$(detect_arch)
log_info "Detected architecture: $ARCH"

# Check if running in proot
if [ -z "$PROOT_SERVICE" ] && [ ! -f "/.proot-env" ]; then
    log_warn "Not running in proot environment. Some features may not work."
fi

# Install Ollama
install_ollama() {
    log_info "Installing Ollama..."
    
    # Create ollama directory
    mkdir -p /root/.ollama
    mkdir -p /usr/local/bin
    
    # Download Ollama for the correct architecture
    OLLAMA_VERSION="v0.1.27"
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-${ARCH}"
    
    log_info "Downloading Ollama from $OLLAMA_URL..."
    
    if command -v curl &> /dev/null; then
        curl -L -o /usr/local/bin/ollama "$OLLAMA_URL"
    elif command -v wget &> /dev/null; then
        wget -O /usr/local/bin/ollama "$OLLAMA_URL"
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    chmod +x /usr/local/bin/ollama
    log_success "Ollama installed to /usr/local/bin/ollama"
}

# Pull default models
pull_default_models() {
    log_info "Pulling default models..."
    
    # Small fast model for chat
    log_info "Pulling llama3 (chat model)..."
    ollama pull llama3 || log_warn "Failed to pull llama3"
    
    # Code generation model
    log_info "Pulling deepseek-coder (code model)..."
    ollama pull deepseek-coder || log_warn "Failed to pull deepseek-coder"
    
    log_success "Default models pulled"
}

# Create Ollama service script
create_service_script() {
    log_info "Creating Ollama service script..."
    
    cat > /usr/local/bin/ollama-service << 'EOF'
#!/bin/bash
# Ollama service wrapper for Android proot

export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_MODELS=/root/.ollama/models

# Start Ollama in serve mode
exec ollama serve
EOF
    
    chmod +x /usr/local/bin/ollama-service
    log_success "Service script created"
}

# Create systemd-like service for proot
create_proot_service() {
    log_info "Creating proot service configuration..."
    
    mkdir -p /etc/proot-services
    
    cat > /etc/proot-services/ollama.json << EOF
{
    "name": "ollama",
    "command": "/usr/local/bin/ollama-service",
    "autostart": true,
    "restart": true,
    "environment": {
        "OLLAMA_HOST": "127.0.0.1:11434",
        "OLLAMA_MODELS": "/root/.ollama/models"
    }
}
EOF
    
    log_success "Proot service configuration created"
}

# Configure environment
configure_environment() {
    log_info "Configuring environment..."
    
    # Add to bashrc if not already present
    if ! grep -q "OLLAMA_HOST" /root/.bashrc 2>/dev/null; then
        cat >> /root/.bashrc << 'EOF'

# Ollama configuration
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_MODELS=/root/.ollama/models
EOF
    fi
    
    log_success "Environment configured"
}

# Main installation
main() {
    log_info "Starting Ollama setup for Unified AI Gateway..."
    
    # Check if Ollama is already installed
    if command -v ollama &> /dev/null; then
        log_warn "Ollama is already installed"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping Ollama installation"
        else
            install_ollama
        fi
    else
        install_ollama
    fi
    
    create_service_script
    create_proot_service
    configure_environment
    
    # Ask to pull default models
    read -p "Pull default models (llama3, deepseek-coder)? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        pull_default_models
    fi
    
    log_success "Ollama setup complete!"
    log_info "Start Ollama with: ollama-service"
    log_info "Or let the Unified Gateway start it automatically"
}

main "$@"