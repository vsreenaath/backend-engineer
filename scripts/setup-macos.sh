#!/bin/bash
# =========================
# macOS Setup Script (Scripts Version)
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
DOCKERFILE="docker/Dockerfile.macos"

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo_error "This script is designed for macOS only. Detected: $(uname -s)"
    exit 1
  fi
  echo_info "Confirmed macOS environment"
}

check_prerequisites() {
  echo_info "Checking prerequisites..."
  local missing_files=()
  if [ ! -f ".env.example" ]; then missing_files+=(".env.example"); fi
  if [ ! -f "docker-compose.yml" ]; then missing_files+=("docker-compose.yml"); fi
  if [ ${#missing_files[@]} -ne 0 ]; then echo_error "Missing required files:"; printf '  - %s\n' "${missing_files[@]}"; exit 1; fi

  if command -v python3 >/dev/null 2>&1; then PYTHON_CMD="python3"
  elif command -v python >/dev/null 2>&1; then PYTHON_CMD="python"
  else echo_error "Python3 not found (brew install python)"; exit 1; fi

  # Adjust sed flavor if GNU sed present
  if sed --version 2>/dev/null | grep -q GNU; then SED_INPLACE="sed -i"; else SED_INPLACE="sed -i ''"; fi

  echo_success "Prerequisites check passed"
}

generate_secret_key() { $PYTHON_CMD -c "import secrets; print(secrets.token_hex(32), end='')"; }

setup_env() {
  echo_info "Setting up environment file..."
  [ -f .env ] && { echo_warn "Deleting existing .env..."; rm -f .env; }
  cp .env.example .env
  chmod 600 .env || true
  local key; key=$(generate_secret_key)
  if grep -q "^SECRET_KEY=" .env; then $SED_INPLACE "s|^SECRET_KEY=.*|SECRET_KEY=$key|" .env; else echo "SECRET_KEY=$key" >> .env; fi
  echo_success "SECRET_KEY updated in .env"
}

update_docker_compose() {
  echo_info "Updating docker-compose.yml to use $DOCKERFILE..."
  if grep -q "dockerfile:" docker-compose.yml; then
    $SED_INPLACE "s|dockerfile:.*|dockerfile: $DOCKERFILE|" docker-compose.yml
  else
    echo_warn "No dockerfile reference found in docker-compose.yml"
  fi
  echo_success "docker-compose.yml updated"
}

check_docker() {
  echo_info "Checking Docker on macOS..."
  command -v docker >/dev/null 2>&1 || { echo_error "Docker not found (install Docker Desktop)"; exit 1; }
  docker info >/dev/null 2>&1 || { echo_error "Docker daemon is not running. Start Docker Desktop."; exit 1; }
  if command -v docker-compose >/dev/null 2>&1; then COMPOSE_CMD="docker-compose"; elif docker compose version >/dev/null 2>&1; then COMPOSE_CMD="docker compose"; else echo_error "docker-compose not available"; exit 1; fi
  echo_success "Docker is available"
}

start_containers() {
  echo_info "Building and starting Docker containers..."
  $COMPOSE_CMD up -d --build || { echo_error "Compose up failed"; exit 1; }
  echo_success "Containers started"
}

apply_migrations() {
  echo_info "Applying database migrations..."; sleep 8
  if $COMPOSE_CMD exec web alembic upgrade head; then echo_success "Migrations applied"; else echo_warn "Upgrade failed, stamping head"; $COMPOSE_CMD exec web alembic stamp head || { echo_error "Stamp failed"; exit 1; }; fi
}

print_completion_info() {
  echo ""; echo_success "🎉 macOS setup complete!"; echo ""; echo "   Problem 1: http://localhost:8000 (docs /docs)"; echo "   Problem 2: http://localhost:8001"; echo "   Problem 3: http://localhost:8002"; echo "   PgAdmin: http://localhost:5050"; echo "   Gateway: http://localhost:8080"; echo "   Prometheus: http://localhost:9090"; echo "   Grafana: http://localhost:3000";
}

main() {
  echo ""; echo -e "${BLUE}================================${NC}"; echo -e "${BLUE}🍎 macOS Docker FastAPI Setup${NC}"; echo -e "${BLUE}================================${NC}"; echo "";
  check_macos; check_prerequisites; setup_env; update_docker_compose; check_docker; start_containers; apply_migrations; print_completion_info
}

main "$@"
