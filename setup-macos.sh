#!/bin/bash
# =========================
# macOS Setup Script
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

# macOS-specific settings
SED_INPLACE="sed -i ''"
DOCKERFILE="Dockerfile.ubuntu"

# Check if we're actually on macOS
check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        echo_error "This script is designed for macOS only. Detected: $(uname -s)"
        exit 1
    fi
    echo_info "Confirmed macOS environment"
}

# Check if required files exist
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    local missing_files=()
    
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
    
    # Check Python availability (prefer python3 on macOS)
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    else
        echo_error "Python not found. Please install Python 3:"
        echo "  brew install python3"
        exit 1
    fi
    
    # Check if sed is GNU sed or BSD sed
    if sed --version 2>/dev/null | grep -q GNU; then
        echo_info "GNU sed detected"
        SED_INPLACE="sed -i"
    else
        echo_info "BSD sed detected (macOS default)"
        SED_INPLACE="sed -i ''"
    fi
    
    echo_success "Prerequisites check passed"
}

# Generate SECRET_KEY using Python
generate_secret_key() {
    $PYTHON_CMD -c "import secrets; print(secrets.token_hex(32), end='')"
}

# Extract value from .env file (macOS compatible)
get_env_value() {
    local key=$1
    local file=${2:-.env}
    
    # Use awk for better compatibility on macOS
    awk -F'=' -v key="$key" '
        $1 == key { 
            gsub(/^["'"'"']|["'"'"']$/, "", $2); 
            print $2; 
            exit 
        }
    ' "$file"
}

# Setup environment file
setup_env() {
    echo_info "Setting up environment file..."
    
    # Delete existing .env with confirmation on macOS
    if [ -f ".env" ]; then
        echo_warn "Deleting existing .env..."
        rm -f .env
    fi
    
    # Copy .env.example to .env
    echo_info "Copying .env.example → .env..."
    cp .env.example .env
    
    # Set restrictive permissions (important on Unix systems)
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

# Update docker-compose.yml for macOS
update_docker_compose() {
    echo_info "Updating docker-compose.yml for macOS..."
    
    # Update Dockerfile reference
    if grep -q "dockerfile:" docker-compose.yml; then
        $SED_INPLACE "s|dockerfile:.*|dockerfile: $DOCKERFILE|" docker-compose.yml
    else
        echo_warn "No dockerfile reference found in docker-compose.yml"
    fi
    
    # Extract Postgres credentials from .env using macOS-compatible method
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

# Check Docker availability on macOS
check_docker() {
    echo_info "Checking Docker on macOS..."
    
    # Check if Docker command exists
    if ! command -v docker >/dev/null 2>&1; then
        echo_error "Docker not found. Please install Docker Desktop for Mac:"
        echo "  https://docs.docker.com/desktop/install/mac-install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo_error "Docker daemon is not running."
        echo_info "Please start Docker Desktop and try again."
        echo_info "You can start it from Applications or run: open -a Docker"
        exit 1
    fi
    
    # Check docker-compose (might be integrated into docker on newer versions)
    if ! docker-compose version >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        echo_error "docker-compose not available."
        echo_info "Please ensure Docker Desktop is properly installed."
        exit 1
    fi
    
    # Determine which compose command to use
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    echo_success "Docker is available and running"
    echo_info "Using compose command: $COMPOSE_CMD"
}

# Build and start containers with enhanced error handling
start_containers() {
    echo_info "Building and starting Docker containers..."
    
    # Show progress with macOS-style output
    printf "Building"
    for i in {1..5}; do 
        printf "."
        sleep 0.3
    done
    printf "\n"
    
    # Capture build output for error analysis
    echo_info "Starting Docker build process..."
    
    if ! build_output=$($COMPOSE_CMD up -d --build 2>&1); then
        echo_error "Docker build/start failed"
        echo ""
        echo_error "Build output:"
        echo "$build_output"
        echo ""
        
        # Analyze common Docker build issues
        if echo "$build_output" | grep -q "network\|timeout\|connection\|resolve"; then
            echo_warn "Network connectivity issues detected:"
            echo "  • Check internet connection"
            echo "  • Try: docker system prune -f"
            echo "  • macOS: Check Docker Desktop network settings"
        fi
        
        if echo "$build_output" | grep -q "disk\|space\|no space left"; then
            echo_warn "Disk space issues detected:"
            echo "  • Free up disk space"
            echo "  • Try: docker system prune -a -f"
            echo "  • macOS: Check Docker Desktop disk usage in Preferences"
        fi
        
        if echo "$build_output" | grep -q "requirements\.txt\|pip\|package\|ModuleNotFoundError"; then
            echo_warn "Python dependency issues detected:"
            echo "  • Check requirements.txt exists and is valid"
            echo "  • Verify Python packages are available"
            echo "  • Try rebuilding: $COMPOSE_CMD build --no-cache"
        fi
        
        if echo "$build_output" | grep -q "Dockerfile\|COPY\|ADD\|No such file"; then
            echo_warn "Dockerfile or file path issues detected:"
            echo "  • Ensure Dockerfile.ubuntu exists in project root"
            echo "  • Check file paths in Dockerfile"
            echo "  • Verify all required files are present"
        fi
        
        if echo "$build_output" | grep -q "port.*already in use\|bind.*address already in use"; then
            echo_warn "Port conflict detected:"
            echo "  • Stop existing containers: $COMPOSE_CMD down"
            echo "  • Check what's using the ports: lsof -i :8000"
            echo "  • Or change ports in docker-compose.yml"
        fi
        
        if echo "$build_output" | grep -q "permission denied\|access denied"; then
            echo_warn "Permission issues detected:"
            echo "  • macOS: Ensure Docker Desktop has necessary permissions"
            echo "  • Check file permissions: ls -la"
            echo "  • Try: sudo $COMPOSE_CMD down && $COMPOSE_CMD up -d --build"
        fi
        
        echo ""
        echo_info "Troubleshooting steps for macOS:"
        echo "  1. Restart Docker Desktop: Docker → Restart"
        echo "  2. Check logs: $COMPOSE_CMD logs"
        echo "  3. Clean Docker: docker system prune -a -f"
        echo "  4. Check Docker Desktop Resources in Preferences"
        echo "  5. Try: $COMPOSE_CMD down && $COMPOSE_CMD up -d --build"
        echo "  6. If still failing: $COMPOSE_CMD build --no-cache"
        
        exit 1
    fi
    
    # Verify containers are running
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        echo_warn "Containers may not be running properly"
        echo_info "Container status:"
        $COMPOSE_CMD ps
        
        echo ""
        echo_info "Checking container logs for issues..."
        $COMPOSE_CMD logs --tail=10
    fi
    
    echo_success "Containers started successfully"
}

# Apply database migrations
apply_migrations() {
    echo_info "Applying database migrations..."
    
    # Wait for services to be ready (macOS might need a bit more time)
    echo_info "Waiting for services to be ready..."
    sleep 8
    
    # Try migration with better error handling
    if $COMPOSE_CMD exec web alembic upgrade head 2>/dev/null; then
        echo_success "Database migrations applied successfully"
    else
        echo_warn "Migration failed or not needed on first run."
        echo_info "You can manually run migrations later with:"
        echo "  $COMPOSE_CMD exec web alembic upgrade head"
    fi
}

# Print completion information with macOS-specific notes
print_completion_info() {
    echo ""
    echo_success "🎉 macOS setup complete!"
    echo ""
    echo -e "${GREEN}🚀 Your application is ready:${NC}"
    echo "   FastAPI: http://localhost:8000"
    echo "   API Docs: http://localhost:8000/docs"
    echo "   PgAdmin: http://localhost:5050"
    echo ""
    echo -e "${GREEN}📝 Useful commands:${NC}"
    echo "   View logs: $COMPOSE_CMD logs -f"
    echo "   Stop: $COMPOSE_CMD down"
    echo "   Restart: $COMPOSE_CMD restart"
    echo "   Shell into container: $COMPOSE_CMD exec web bash"
    echo ""
    echo -e "${BLUE}💡 macOS Tips:${NC}"
    echo "   - If you get permission errors, try: sudo $COMPOSE_CMD down"
    echo "   - Docker Desktop must be running for the app to work"
    echo "   - Use Command+C to stop the logs if running in foreground"
}

# Cleanup function for error handling
cleanup_on_error() {
    echo_error "Setup failed. Cleaning up..."
    $COMPOSE_CMD down 2>/dev/null || docker-compose down 2>/dev/null || true
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# Main execution function
main() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}🍎 macOS Docker FastAPI Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    check_macos
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