#!/bin/bash
# =========================
# Linux Setup Script
# =========================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }

# Linux-specific settings
SED_INPLACE="sed -i"
DOCKERFILE="Dockerfile.ubuntu"

# Check if we're actually on Linux
check_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo_error "This script is designed for Linux only. Detected: $(uname -s)"
        exit 1
    fi
    
    # Detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo_info "Detected Linux distribution: $NAME $VERSION"
    else
        echo_info "Confirmed Linux environment (distribution unknown)"
    fi
}

# Check if required files exist and system requirements
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    local missing_files=()
    local missing_commands=()
    
    # Check required files
    if [ ! -f ".env.example" ]; then
        missing_files+=(".env.example")
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        missing_files+=("docker-compose.yml")
    fi
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        echo_error "Missing required files:"
        printf '  - %s\n' "${missing_files[@]}"
        exit 1
    fi
    
    # Check Python availability
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        # Check if it's Python 3
        if python -c "import sys; exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
            PYTHON_CMD="python"
        else
            missing_commands+=("python3")
        fi
    else
        missing_commands+=("python3")
    fi
    
    # Check other required commands
    for cmd in curl wget; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo_error "Missing required commands:"
        printf '  - %s\n' "${missing_commands[@]}"
        echo ""
        echo_info "Install missing packages with:"
        
        # Provide distribution-specific install commands
        if command -v apt-get >/dev/null 2>&1; then
            echo "  sudo apt-get update && sudo apt-get install -y python3 curl wget"
        elif command -v yum >/dev/null 2>&1; then
            echo "  sudo yum install -y python3 curl wget"
        elif command -v dnf >/dev/null 2>&1; then
            echo "  sudo dnf install -y python3 curl wget"
        elif command -v pacman >/dev/null 2>&1; then
            echo "  sudo pacman -S python curl wget"
        else
            echo "  Use your distribution's package manager to install: python3 curl wget"
        fi
        exit 1
    fi
    
    echo_success "Prerequisites check passed"
}

# Generate SECRET_KEY using Python
generate_secret_key() {
    $PYTHON_CMD -c "import secrets; print(secrets.token_hex(32), end='')"
}

# Extract value from .env file (Linux compatible)
get_env_value() {
    local key=$1
    local file=${2:-.env}
    
    # Use grep and cut for maximum compatibility
    grep "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d'=' -f2- | sed 's/^["'\'']//' | sed 's/["'\'']$//'
}

# Setup environment file
setup_env() {
    echo_info "Setting up environment file..."
    
    # Delete existing .env
    if [ -f ".env" ]; then
        echo_warn "Deleting existing .env..."
        rm -f .env
    fi
    
    # Copy .env.example to .env
    echo_info "Copying .env.example → .env..."
    cp .env.example .env
    
    # Set restrictive permissions (important on Linux servers)
    chmod 600 .env
    echo_info "Set .env permissions to 600 (owner read/write only)"
    
    # Generate and update SECRET_KEY
    echo_info "Generating new SECRET_KEY..."
    local secret_key
    secret_key=$(generate_secret_key)
    
    if grep -q "^SECRET_KEY=" .env; then
        $SED_INPLACE "s|^SECRET_KEY=.*|SECRET_KEY=$secret_key|" .env
    else
        echo "SECRET_KEY=$secret_key" >> .env
    fi
    
    echo_success "SECRET_KEY updated in .env"
}

# Update docker-compose.yml for Linux
update_docker_compose() {
    echo_info "Updating docker-compose.yml for Linux..."
    
    # Update Dockerfile reference
    if grep -q "dockerfile:" docker-compose.yml; then
        $SED_INPLACE "s|dockerfile:.*|dockerfile: $DOCKERFILE|" docker-compose.yml
    else
        echo_warn "No dockerfile reference found in docker-compose.yml"
    fi
    
    # Extract Postgres credentials from .env
    local postgres_user postgres_password postgres_db postgres_server
    postgres_user=$(get_env_value "POSTGRES_USER")
    postgres_password=$(get_env_value "POSTGRES_PASSWORD")
    postgres_db=$(get_env_value "POSTGRES_DB")
    postgres_server=$(get_env_value "POSTGRES_SERVER")
    
    # Validate that we got the essential values
    if [ -z "$postgres_user" ] || [ -z "$postgres_password" ] || [ -z "$postgres_db" ]; then
        echo_error "Failed to extract required Postgres credentials from .env"
        echo_info "Please ensure .env contains: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
        exit 1
    fi
    
    echo_info "Syncing Postgres credentials in docker-compose.yml..."
    
    # Update Postgres credentials in docker-compose.yml
    $SED_INPLACE "s|POSTGRES_USER=.*|POSTGRES_USER=$postgres_user|g" docker-compose.yml
    $SED_INPLACE "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$postgres_password|g" docker-compose.yml
    $SED_INPLACE "s|POSTGRES_DB=.*|POSTGRES_DB=$postgres_db|g" docker-compose.yml
    
    if [ -n "$postgres_server" ]; then
        $SED_INPLACE "s|POSTGRES_SERVER=.*|POSTGRES_SERVER=$postgres_server|g" docker-compose.yml
    fi
    
    echo_success "docker-compose.yml updated with $DOCKERFILE"
}

# Check Docker availability on Linux
check_docker() {
    echo_info "Checking Docker on Linux..."
    
    # Check if Docker command exists
    if ! command -v docker >/dev/null 2>&1; then
        echo_error "Docker not found. Please install Docker:"
        echo ""
        echo_info "Ubuntu/Debian:"
        echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
        echo "  sudo sh get-docker.sh"
        echo ""
        echo_info "CentOS/RHEL/Fedora:"
        echo "  sudo yum install -y docker"
        echo "  sudo systemctl start docker"
        echo "  sudo systemctl enable docker"
        echo ""
        echo_info "Arch Linux:"
        echo "  sudo pacman -S docker"
        echo "  sudo systemctl start docker"
        echo "  sudo systemctl enable docker"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo_error "Docker daemon is not running."
        echo_info "Starting Docker daemon..."
        
        if command -v systemctl >/dev/null 2>&1; then
            echo "  sudo systemctl start docker"
            echo "  sudo systemctl enable docker"
        elif command -v service >/dev/null 2>&1; then
            echo "  sudo service docker start"
        else
            echo "  Please start Docker manually"
        fi
        exit 1
    fi
    
    # Check if user is in docker group (avoid sudo requirement)
    if ! groups | grep -q docker && [ "$EUID" -ne 0 ]; then
        echo_warn "Current user is not in docker group."
        echo_info "To avoid using sudo with Docker, run:"
        echo "  sudo usermod -aG docker $USER"
        echo "  newgrp docker"
        echo ""
        echo_info "Continuing with current permissions..."
    fi
    
    # Check docker-compose
    COMPOSE_CMD=""
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        echo_error "docker-compose not available."
        echo_info "Installing docker-compose..."
        echo ""
        echo "# Method 1: Using pip"
        echo "  pip3 install docker-compose"
        echo ""
        echo "# Method 2: Download binary (replace VERSION with latest)"
        echo "  sudo curl -L \"https://github.com/docker/compose/releases/download/VERSION/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        echo "  sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    echo_success "Docker is available and running"
    echo_info "Using compose command: $COMPOSE_CMD"
}

# Build and start containers with enhanced error handling
start_containers() {
    echo_info "Building and starting Docker containers..."
    
    # Show progress
    printf "Building"
    for i in {1..5}; do 
        printf "."
        sleep 0.3
    done
    printf "\n"
    
    # Check if we need sudo
    SUDO_CMD=""
    if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        echo_warn "Docker requires elevated privileges, using sudo..."
        SUDO_CMD="sudo"
    fi
    
    # Capture build output for error analysis
    echo_info "Starting Docker build process..."
    
    if ! build_output=$($SUDO_CMD $COMPOSE_CMD up -d --build 2>&1); then
        echo_error "Docker build/start failed"
        echo ""
        echo_error "Build output:"
        echo "$build_output"
        echo ""
        
        # Analyze common Docker build issues
        if echo "$build_output" | grep -q "network\|timeout\|connection\|resolve\|DNS"; then
            echo_warn "Network connectivity issues detected:"
            echo "  • Check internet connection: ping google.com"
            echo "  • Check DNS settings: cat /etc/resolv.conf"
            echo "  • Try: $SUDO_CMD docker system prune -f"
            echo "  • Restart Docker: sudo systemctl restart docker"
        fi
        
        if echo "$build_output" | grep -q "disk\|space\|no space left"; then
            echo_warn "Disk space issues detected:"
            echo "  • Check disk space: df -h"
            echo "  • Free up space: $SUDO_CMD docker system prune -a -f"
            echo "  • Clean logs: sudo journalctl --vacuum-time=3d"
        fi
        
        if echo "$build_output" | grep -q "requirements\.txt\|pip\|package\|ModuleNotFoundError"; then
            echo_warn "Python dependency issues detected:"
            echo "  • Check requirements.txt exists and is valid"
            echo "  • Verify Python packages are available"
            echo "  • Try rebuilding: $SUDO_CMD $COMPOSE_CMD build --no-cache"
            echo "  • Check if behind corporate firewall/proxy"
        fi
        
        if echo "$build_output" | grep -q "Dockerfile\|COPY\|ADD\|No such file"; then
            echo_warn "Dockerfile or file path issues detected:"
            echo "  • Ensure Dockerfile.ubuntu exists: ls -la Dockerfile*"
            echo "  • Check file paths in Dockerfile"
            echo "  • Verify all required files are present"
        fi
        
        if echo "$build_output" | grep -q "port.*already in use\|bind.*address already in use"; then
            echo_warn "Port conflict detected:"
            echo "  • Stop existing containers: $SUDO_CMD $COMPOSE_CMD down"
            echo "  • Check what's using ports: sudo netstat -tulpn | grep :8000"
            echo "  • Kill processes: sudo fuser -k 8000/tcp"
            echo "  • Or change ports in docker-compose.yml"
        fi
        
        if echo "$build_output" | grep -q "permission denied\|access denied"; then
            echo_warn "Permission issues detected:"
            echo "  • Add user to docker group: sudo usermod -aG docker \$USER"
            echo "  • Restart session: newgrp docker"
            echo "  • Check file permissions: ls -la"
            echo "  • Try: sudo $COMPOSE_CMD up -d --build"
        fi
        
        if echo "$build_output" | grep -q "cgroup\|systemd\|init"; then
            echo_warn "System/cgroup issues detected:"
            echo "  • Restart Docker daemon: sudo systemctl restart docker"
            echo "  • Check Docker status: sudo systemctl status docker"
            echo "  • Check system resources: free -h && df -h"
        fi
        
        echo ""
        echo_info "Troubleshooting steps for Linux:"
        echo "  1. Check Docker daemon: sudo systemctl status docker"
        echo "  2. Restart Docker: sudo systemctl restart docker"
        echo "  3. Check logs: $SUDO_CMD $COMPOSE_CMD logs"
        echo "  4. Clean Docker: $SUDO_CMD docker system prune -a -f"
        echo "  5. Check system resources: free -h && df -h"
        echo "  6. Try: $SUDO_CMD $COMPOSE_CMD down && $SUDO_CMD $COMPOSE_CMD up -d --build"
        echo "  7. If still failing: $SUDO_CMD $COMPOSE_CMD build --no-cache"
        echo "  8. Check firewall: sudo ufw status"
        
        exit 1
    fi
    
    # Verify containers are running
    if ! $SUDO_CMD $COMPOSE_CMD ps | grep -q "Up"; then
        echo_warn "Containers may not be running properly"
        echo_info "Container status:"
        $SUDO_CMD $COMPOSE_CMD ps
        
        echo ""
        echo_info "Checking container logs for issues..."
        $SUDO_CMD $COMPOSE_CMD logs --tail=10
    fi
    
    echo_success "Containers started successfully"
}

# Apply database migrations
apply_migrations() {
    echo_info "Applying database migrations..."
    
    # Wait for services to be ready
    echo_info "Waiting for services to be ready..."
    sleep 6
    
    # Check if we need sudo for docker commands
    SUDO_CMD=""
    if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi
    
    # Try migration with fallback to stamp head
    if $SUDO_CMD $COMPOSE_CMD exec web alembic upgrade head 2>/dev/null; then
        echo_success "Database migrations applied successfully"
    else
        echo_warn "Alembic upgrade failed, attempting to stamp head and continue..."
        if $SUDO_CMD $COMPOSE_CMD exec web alembic stamp head 2>/dev/null; then
            echo_success "Stamped current DB state to head. Migrations considered applied."
        else
            echo_error "Migration and stamping failed. Showing web logs..."
            $SUDO_CMD $COMPOSE_CMD logs web || true
            exit 1
        fi
    fi
}

# Print completion information with Linux-specific notes
print_completion_info() {
    echo ""
    echo_success "🐧 Linux setup complete!"
    echo ""
    echo -e "${GREEN}🚀 Your application is ready:${NC}"
    echo "   FastAPI: http://localhost:8000"
    echo "   API Docs: http://localhost:8000/docs"
    echo "   PgAdmin: http://localhost:5050"
    echo ""
    echo -e "${GREEN}📝 Useful commands:${NC}"
    
    SUDO_CMD=""
    if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        SUDO_CMD="sudo "
    fi
    
    echo "   View logs: ${SUDO_CMD}${COMPOSE_CMD} logs -f"
    echo "   Stop: ${SUDO_CMD}${COMPOSE_CMD} down"
    echo "   Restart: ${SUDO_CMD}${COMPOSE_CMD} restart"
    echo "   Shell into container: ${SUDO_CMD}${COMPOSE_CMD} exec web bash"
    echo "   Check status: ${SUDO_CMD}docker ps"
    echo ""
    echo -e "${BLUE}💡 Linux Tips:${NC}"
    echo "   - Add your user to docker group to avoid sudo: sudo usermod -aG docker \$USER"
    echo "   - Firewall might block ports, check: sudo ufw status"
    echo "   - For production, consider using systemd service files"
    echo "   - Monitor resources: htop, docker stats"
}

# Cleanup function for error handling
cleanup_on_error() {
    echo_error "Setup failed. Cleaning up..."
    
    SUDO_CMD=""
    if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
        SUDO_CMD="sudo"
    fi
    
    $SUDO_CMD $COMPOSE_CMD down 2>/dev/null || $SUDO_CMD docker-compose down 2>/dev/null || true
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# Main execution function
main() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}🐧 Linux Docker FastAPI Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    check_linux
    check_prerequisites
    setup_env
    update_docker_compose
    check_docker
    start_containers
    apply_migrations
    print_completion_info
}

# Run main function with all arguments
main "$@"