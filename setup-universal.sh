#!/bin/bash
# =========================
# Universal Fallback Setup Script
# For Solaris, FreeBSD, OpenBSD, AIX, and other Unix-like systems
# =========================

set -e  # Exit on any error

# ANSI color codes (should work on most terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fallback to plain text if colors don't work
if [ -t 1 ] && [ -n "$TERM" ] && [ "$TERM" != "dumb" ]; then
    USE_COLORS=true
else
    USE_COLORS=false
fi

echo_info() {
    if [ "$USE_COLORS" = true ]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    else
        echo "INFO: $1"
    fi
}

echo_warn() {
    if [ "$USE_COLORS" = true ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    else
        echo "WARNING: $1"
    fi
}

echo_error() {
    if [ "$USE_COLORS" = true ]; then
        echo -e "${RED}❌ $1${NC}"
    else
        echo "ERROR: $1"
    fi
}

echo_success() {
    if [ "$USE_COLORS" = true ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo "SUCCESS: $1"
    fi
}

# Detect OS and architecture
detect_system() {
    OS_NAME=$(uname -s)
    OS_ARCH=$(uname -m)
    OS_RELEASE=""
    
    # Try to get OS release information
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_RELEASE="$NAME $VERSION"
    elif [ -f /etc/release ]; then
        OS_RELEASE=$(head -n1 /etc/release)
    elif [ -f /usr/lib/os-release ]; then
        . /usr/lib/os-release
        OS_RELEASE="$NAME $VERSION"
    fi
    
    echo_info "Detected system: $OS_NAME $OS_ARCH"
    if [ -n "$OS_RELEASE" ]; then
        echo_info "OS Release: $OS_RELEASE"
    fi
    
    # Set OS-specific configurations
    case "$OS_NAME" in
        "Linux")
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="linux"
            ;;
        "Darwin")
            SED_INPLACE="sed -i ''"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="macos"
            ;;
        "FreeBSD")
            SED_INPLACE="sed -i ''"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="freebsd"
            echo_warn "FreeBSD detected - Docker support may be limited"
            ;;
        "OpenBSD")
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="openbsd"
            echo_warn "OpenBSD detected - Docker support may be limited"
            ;;
        "NetBSD")
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="netbsd"
            echo_warn "NetBSD detected - Docker support may be limited"
            ;;
        "SunOS")
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="solaris"
            echo_warn "Solaris/SunOS detected - Docker support may be limited"
            ;;
        "AIX")
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="aix"
            echo_warn "AIX detected - Docker support may be limited"
            ;;
        "MINGW"*|"CYGWIN"*|"MSYS"*)
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.windows"
            PLATFORM_TYPE="windows"
            echo_warn "Windows environment detected - consider using PowerShell script instead"
            ;;
        *)
            SED_INPLACE="sed -i"
            DOCKERFILE="Dockerfile.ubuntu"
            PLATFORM_TYPE="unknown"
            echo_warn "Unknown OS: $OS_NAME - proceeding with generic Unix settings"
            ;;
    esac
    
    echo_info "Using Dockerfile: $DOCKERFILE"
    echo_info "Platform type: $PLATFORM_TYPE"
}

# Check for required tools with fallbacks
check_prerequisites() {
    echo_info "Checking prerequisites for $OS_NAME..."
    
    local missing_files=()
    local missing_commands=()
    local python_cmd=""
    
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
    
    # Check Python (try multiple versions)
    for py_cmd in python3 python3.11 python3.10 python3.9 python3.8 python; do
        if command -v "$py_cmd" >/dev/null 2>&1; then
            # Verify it's Python 3
            if "$py_cmd" -c "import sys; exit(0 if sys.version_info[0] >= 3 else 1)" 2>/dev/null; then
                python_cmd="$py_cmd"
                break
            fi
        fi
    done
    
    if [ -z "$python_cmd" ]; then
        missing_commands+=("python3")
    fi
    
    # Check for basic utilities
    for cmd in curl wget; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo_error "Missing required commands:"
        printf '  - %s\n' "${missing_commands[@]}"
        echo ""
        echo_info "Install missing packages using your system's package manager:"
        
        case "$PLATFORM_TYPE" in
            "freebsd")
                echo "  FreeBSD: pkg install python3 curl wget"
                ;;
            "openbsd")
                echo "  OpenBSD: pkg_add python3 curl wget"
                ;;
            "solaris")
                echo "  Solaris: pkgutil -i python3 curl wget"
                echo "      or: pkg install python3 curl wget"
                ;;
            "aix")
                echo "  AIX: installp -a -d /path/to/packages python3 curl wget"
                ;;
            *)
                echo "  Use your system's package manager to install: python3 curl wget"
                ;;
        esac
        exit 1
    fi
    
    PYTHON_CMD="$python_cmd"
    echo_success "Prerequisites check passed (using $PYTHON_CMD)"
}

# Generate SECRET_KEY with multiple fallback methods
generate_secret_key() {
    local secret_key=""
    
    # Method 1: Python secrets module
    if [ -n "$PYTHON_CMD" ]; then
        if secret_key=$($PYTHON_CMD -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null); then
            echo "$secret_key"
            return 0
        fi
    fi
    
    # Method 2: OpenSSL
    if command -v openssl >/dev/null 2>&1; then
        if secret_key=$(openssl rand -hex 32 2>/dev/null); then
            echo "$secret_key"
            return 0
        fi
    fi
    
    # Method 3: /dev/urandom (most Unix systems)
    if [ -r /dev/urandom ]; then
        if secret_key=$(head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n' 2>/dev/null); then
            echo "$secret_key"
            return 0
        fi
    fi
    
    # Method 4: Fallback using date and random
    if command -v od >/dev/null 2>&1; then
        secret_key=$(echo "$RANDOM$(date)$RANDOM" | od -A n -t x1 | tr -d ' \n' | head -c 64)
        echo "$secret_key"
        return 0
    fi
    
    # Method 5: Last resort
    echo_error "Unable to generate secure random key with available methods"
    echo_info "Please manually set SECRET_KEY in .env file"
    echo "$(date | md5sum 2>/dev/null || echo 'CHANGE_THIS_INSECURE_KEY_MANUALLY')" | head -c 32
}

# Extract value from .env file (universal method)
get_env_value() {
    local key=$1
    local file=${2:-.env}
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    # Use awk for maximum compatibility across Unix variants
    awk -F'=' -v key="^$key$" '
        $1 ~ key { 
            gsub(/^["'"'"']|["'"'"']$/, "", $2); 
            print $2; 
            exit 
        }
    ' "$file" 2>/dev/null
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
    
    # Set restrictive permissions (if chmod supports it)
    if chmod 600 .env 2>/dev/null; then
        echo_info "Set .env permissions to 600 (owner read/write only)"
    else
        echo_warn "Could not set restrictive permissions on .env file"
    fi
    
    # Generate and update SECRET_KEY
    echo_info "Generating new SECRET_KEY..."
    local secret_key
    secret_key=$(generate_secret_key)
    
    if grep -q "^SECRET_KEY=" .env 2>/dev/null; then
        $SED_INPLACE "s|^SECRET_KEY=.*|SECRET_KEY=$secret_key|" .env
    else
        echo "SECRET_KEY=$secret_key" >> .env
    fi
    
    echo_success "SECRET_KEY updated in .env"
}

# Update docker-compose.yml
update_docker_compose() {
    echo_info "Updating docker-compose.yml..."
    
    # Update Dockerfile reference
    if grep -q "dockerfile:" docker-compose.yml 2>/dev/null; then
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

# Check Docker availability (universal)
check_docker() {
    echo_info "Checking Docker availability on $OS_NAME..."
    
    # Check if Docker command exists
    if ! command -v docker >/dev/null 2>&1; then
        echo_error "Docker not found."
        echo ""
        echo_info "Docker installation instructions for $OS_NAME:"
        
        case "$PLATFORM_TYPE" in
            "linux")
                echo "  • Ubuntu/Debian: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
                echo "  • CentOS/RHEL: sudo yum install docker && sudo systemctl start docker"
                echo "  • Arch: sudo pacman -S docker && sudo systemctl start docker"
                ;;
            "macos")
                echo "  • Install Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
                ;;
            "freebsd")
                echo "  • FreeBSD: pkg install docker"
                echo "  • Note: Docker support on FreeBSD is experimental"
                ;;
            "solaris")
                echo "  • Solaris: Docker is not officially supported"
                echo "  • Consider using containers via Solaris Zones"
                ;;
            *)
                echo "  • Check Docker documentation for $OS_NAME support"
                echo "  • Some systems may not support Docker directly"
                ;;
        esac
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo_error "Docker daemon is not running."
        echo_info "Starting Docker daemon..."
        
        case "$PLATFORM_TYPE" in
            "linux")
                if command -v systemctl >/dev/null 2>&1; then
                    echo "  sudo systemctl start docker"
                    echo "  sudo systemctl enable docker"
                elif command -v service >/dev/null 2>&1; then
                    echo "  sudo service docker start"
                ;;
            *)
                echo "  Please start Docker daemon manually for your system"
                ;;
        esac
        exit 1
    fi
    
    # Check docker-compose availability
    COMPOSE_CMD=""
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        echo_error "docker-compose not available."
        echo_info "Installing docker-compose for $OS_NAME:"
        
        case "$PLATFORM_TYPE" in
            "linux"|"macos")
                echo "  • Method 1: pip3 install docker-compose"
                echo "  • Method 2: Download binary from GitHub releases"
                ;;
            "freebsd")
                echo "  • FreeBSD: pkg install py-docker-compose"
                ;;
            *)
                echo "  • Check docker-compose documentation for your system"
                ;;
        esac
        exit 1
    fi
    
    echo_success "Docker is available and running"
    echo_info "Using compose command: $COMPOSE_CMD"
}

# Build and start containers with comprehensive error handling
start_containers() {
    echo_info "Building and starting Docker containers..."
    
    # Show progress
    printf "Building"
    for i in 1 2 3 4 5; do 
        printf "."
        sleep 0.3
    done
    printf "\n"
    
    # Check if we need sudo (for Linux-like systems)
    SUDO_CMD=""
    if [ "$PLATFORM_TYPE" = "linux" ] || [ "$PLATFORM_TYPE" = "freebsd" ] || [ "$PLATFORM_TYPE" = "openbsd" ]; then
        if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
            echo_warn "Docker requires elevated privileges, using sudo..."
            SUDO_CMD="sudo"
        fi
    fi
    
    # Capture build output for comprehensive error analysis
    echo_info "Starting Docker build process..."
    
    if ! build_output=$($SUDO_CMD $COMPOSE_CMD up -d --build 2>&1); then
        echo_error "Docker build/start failed on $OS_NAME"
        echo ""
        echo_error "Build output:"
        echo "$build_output"
        echo ""
        
        # Comprehensive error analysis
        if echo "$build_output" | grep -qi "network\|timeout\|connection\|resolve\|dns\|unreachable"; then
            echo_warn "Network connectivity issues detected:"
            echo "  • Check internet connection: ping -c 3 8.8.8.8"
            echo "  • Check DNS resolution: nslookup google.com"
            echo "  • Try: $SUDO_CMD docker system prune -f"
            case "$PLATFORM_TYPE" in
                "linux") echo "  • Restart networking: sudo systemctl restart NetworkManager" ;;
                "freebsd") echo "  • Check network config: ifconfig" ;;
                "solaris") echo "  • Check network services: svcs -a | grep network" ;;
            esac
        fi
        
        if echo "$build_output" | grep -qi "disk\|space\|no space left\|filesystem full"; then
            echo_warn "Disk space issues detected:"
            echo "  • Check disk space: df -h"
            echo "  • Free up space: $SUDO_CMD docker system prune -a -f"
            case "$PLATFORM_TYPE" in
                "linux") echo "  • Clean package cache and logs" ;;
                "solaris") echo "  • Check ZFS pool: zpool list" ;;
                "freebsd") echo "  • Check UFS usage: du -sh /*" ;;
            esac
        fi
        
        if echo "$build_output" | grep -qi "requirements\.txt\|pip\|package\|modulenotfounderror\|importerror"; then
            echo_warn "Python dependency issues detected:"
            echo "  • Check requirements.txt exists and is valid"
            echo "  • Verify Python packages are available"
            echo "  • Try rebuilding: $SUDO_CMD $COMPOSE_CMD build --no-cache"
            echo "  • Check if behind corporate firewall/proxy"
            echo "  • Python path issues on $OS_NAME"
        fi
        
        if echo "$build_output" | grep -qi "dockerfile\|copy\|add\|no such file\|not found"; then
            echo_warn "Dockerfile or file path issues detected:"
            echo "  • Ensure $DOCKERFILE exists: ls -la Dockerfile*"
            echo "  • Check file paths in Dockerfile"
            echo "  • Verify all required files are present"
            echo "  • File system case sensitivity on $OS_NAME"
        fi
        
        if echo "$build_output" | grep -qi "port.*already in use\|bind.*address already in use\|address in use"; then
            echo_warn "Port conflict detected:"
            echo "  • Stop existing containers: $SUDO_CMD $COMPOSE_CMD down"
            case "$PLATFORM_TYPE" in
                "linux"|"macos") echo "  • Check what's using ports: netstat -tulpn | grep :8000" ;;
                "freebsd"|"openbsd") echo "  • Check ports: netstat -an | grep 8000" ;;
                "solaris") echo "  • Check ports: netstat -an | grep 8000" ;;
            esac
            echo "  • Or change ports in docker-compose.yml"
        fi
        
        if echo "$build_output" | grep -qi "permission denied\|access denied\|operation not permitted"; then
            echo_warn "Permission issues detected:"
            case "$PLATFORM_TYPE" in
                "linux")
                    echo "  • Add user to docker group: sudo usermod -aG docker \$USER"
                    echo "  • Restart session: newgrp docker"
                    ;;
                "freebsd")
                    echo "  • Add user to docker group: sudo pw groupmod docker -m \$USER"
                    ;;
                "solaris")
                    echo "  • Check user privileges and zones"
                    ;;
            esac
            echo "  • Check file permissions: ls -la"
        fi
        
        if echo "$build_output" | grep -qi "cgroup\|systemd\|init\|containerd"; then
            echo_warn "System/container runtime issues detected:"
            case "$PLATFORM_TYPE" in
                "linux")
                    echo "  • Restart Docker daemon: sudo systemctl restart docker"
                    echo "  • Check Docker status: sudo systemctl status docker"
                    ;;
                "freebsd")
                    echo "  • Restart Docker: sudo service docker restart"
                    ;;
                *)
                    echo "  • Restart Docker service for your system"
                    ;;
            esac
        fi
        
        if echo "$build_output" | grep -qi "unsupported\|not supported\|architecture"; then
            echo_warn "Platform/architecture compatibility issues:"
            echo "  • OS: $OS_NAME, Arch: $OS_ARCH may have limited Docker support"
            echo "  • Check Docker documentation for $OS_NAME support"
            echo "  • Consider using alternative containerization"
        fi
        
        echo ""
        echo_info "Troubleshooting steps for $OS_NAME:"
        echo "  1. Check system logs for Docker issues"
        echo "  2. Restart Docker service"
        echo "  3. Check logs: $SUDO_CMD $COMPOSE_CMD logs"
        echo "  4. Clean Docker: $SUDO_CMD docker system prune -a -f"
        echo "  5. Check system resources: free -h && df -h"
        echo "  6. Try: $SUDO_CMD $COMPOSE_CMD down && $SUDO_CMD $COMPOSE_CMD up -d --build"
        echo "  7. If still failing: $SUDO_CMD $COMPOSE_CMD build --no-cache"
        
        case "$PLATFORM_TYPE" in
            "linux")
                echo "  8. Check firewall: sudo iptables -L || sudo ufw status"
                echo "  9. Check SELinux: getenforce (if applicable)"
                ;;
            "freebsd")
                echo "  8. Check firewall: sudo pfctl -sr"
                echo "  9. Check jail configuration if using jails"
                ;;
            "solaris")
                echo "  8. Check zones: zoneadm list -cv"
                echo "  9. Check SMF services: svcs -a | grep docker"
                ;;
        esac
        
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
    
    echo_success "Containers started successfully on $OS_NAME"
}

# Apply database migrations
apply_migrations() {
    echo_info "Applying database migrations..."
    
    # Wait for services to be ready (may need more time on some systems)
    echo_info "Waiting for services to be ready..."
    sleep 8
    
    # Check if we need sudo
    SUDO_CMD=""
    if [ "$PLATFORM_TYPE" = "linux" ] || [ "$PLATFORM_TYPE" = "freebsd" ] || [ "$PLATFORM_TYPE" = "openbsd" ]; then
        if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
            SUDO_CMD="sudo"
        fi
    fi
    
    # Try migration with error handling
    if $SUDO_CMD $COMPOSE_CMD exec web alembic upgrade head 2>/dev/null; then
        echo_success "Database migrations applied successfully"
    else
        echo_warn "Migration failed or not needed on first run."
        echo_info "You can manually run migrations later with:"
        echo "  $SUDO_CMD $COMPOSE_CMD exec web alembic upgrade head"
    fi
}

# Print completion information with OS-specific notes
print_completion_info() {
    echo ""
    echo_success "🌍 Universal setup complete for $OS_NAME!"
    echo ""
    if [ "$USE_COLORS" = true ]; then
        echo -e "${GREEN}🚀 Your application is ready:${NC}"
    else
        echo "Your application is ready:"
    fi
    echo "   FastAPI: http://localhost:8000"
    echo "   API Docs: http://localhost:8000/docs"
    echo "   PgAdmin: http://localhost:5050"
    echo ""
    
    if [ "$USE_COLORS" = true ]; then
        echo -e "${GREEN}📝 Useful commands:${NC}"
    else
        echo "Useful commands:"
    fi
    
    SUDO_CMD=""
    if [ "$PLATFORM_TYPE" = "linux" ] || [ "$PLATFORM_TYPE" = "freebsd" ] || [ "$PLATFORM_TYPE" = "openbsd" ]; then
        if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
            SUDO_CMD="sudo "
        fi
    fi
    
    echo "   View logs: ${SUDO_CMD}${COMPOSE_CMD} logs -f"
    echo "   Stop: ${SUDO_CMD}${COMPOSE_CMD} down"
    echo "   Restart: ${SUDO_CMD}${COMPOSE_CMD} restart"
    echo "   Shell into container: ${SUDO_CMD}${COMPOSE_CMD} exec web bash"
    echo "   Check status: ${SUDO_CMD}docker ps"
    echo ""
    
    if [ "$USE_COLORS" = true ]; then
        echo -e "${BLUE}💡 Tips for $OS_NAME:${NC}"
    else
        echo "Tips for $OS_NAME:"
    fi
    
    case "$PLATFORM_TYPE" in
        "linux")
            echo "   - Add user to docker group: sudo usermod -aG docker \$USER"
            echo "   - Monitor resources: htop, docker stats"
            ;;
        "macos")
            echo "   - Docker Desktop must be running"
            echo "   - Check Docker Desktop preferences for resources"
            ;;
        "freebsd")
            echo "   - Docker on FreeBSD is experimental"
            echo "   - Consider using FreeBSD jails as alternative"
            ;;
        "solaris")
            echo "   - Docker support is limited on Solaris"
            echo "   - Consider Solaris Zones for containerization"
            ;;
        "aix")
            echo "   - Docker support is not available on AIX"
            echo "   - Consider IBM PowerVM or WPARs"
            ;;
        *)
            echo "   - Docker support varies by system"
            echo "   - Check system-specific documentation"
            ;;
    esac
    
    echo ""
    if echo "$build_output" | grep -qi "warning\|deprecated"; then
        echo_warn "Some warnings were detected during build - check logs if issues occur"
    fi
}

# Cleanup function for error handling
cleanup_on_error() {
    echo_error "Setup failed. Cleaning up..."
    
    SUDO_CMD=""
    if [ "$PLATFORM_TYPE" = "linux" ] || [ "$PLATFORM_TYPE" = "freebsd" ] || [ "$PLATFORM_TYPE" = "openbsd" ]; then
        if ! docker info >/dev/null 2>&1 && [ "$EUID" -ne 0 ]; then
            SUDO_CMD="sudo"
        fi
    fi
    
    $SUDO_CMD $COMPOSE_CMD down 2>/dev/null || $SUDO_CMD docker-compose down 2>/dev/null || true
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# Main execution function
main() {
    echo ""
    if [ "$USE_COLORS" = true ]; then
        echo -e "${CYAN}================================${NC}"
        echo -e "${CYAN}🌍 Universal Docker FastAPI Setup${NC}"
        echo -e "${CYAN}================================${NC}"
    else
        echo "================================"
        echo "Universal Docker FastAPI Setup"
        echo "================================"
    fi
    echo ""
    
    detect_system
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
                elif command -v rc-service >/dev/null 2>&1; then
                    echo "  sudo rc-service docker start"
                fi
                ;;
            "macos")
                echo "  Start Docker Desktop from Applications"
                echo "  Or run: open -a Docker"
                ;;
            "freebsd")
                echo "  sudo service docker start"