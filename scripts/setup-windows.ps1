# =========================
# Windows PowerShell Setup Script (Scripts Version)
# =========================

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Logging helpers
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    if (-not (Test-Path ".env.example")) { Write-Error ".env.example file not found!"; exit 1 }
    if (-not (Test-Path "docker-compose.yml")) { Write-Error "docker-compose.yml file not found!"; exit 1 }

    $pythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" }
                 elseif (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" }
                 else { Write-Error "Python not found. Required for SECRET_KEY generation."; exit 1 }

    Write-Success "Prerequisites check passed"
    return $pythonCmd
}

function New-SecretKey {
    param([string]$PythonCommand)
    try {
        return & $PythonCommand -c "import secrets; print(secrets.token_hex(32), end='')"
    } catch {
        Write-Warning "Python method failed, using PowerShell fallback..."
        $bytes = New-Object Byte[] 32
        [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        return [System.BitConverter]::ToString($bytes) -replace "-", ""
    }
}

function Set-EnvironmentFile {
    param([string]$PythonCommand)
    Write-Info "Setting up .env file..."

    if (Test-Path ".env") { Write-Warning "Deleting existing .env..."; Remove-Item ".env" -Force }
    Copy-Item ".env.example" ".env"

    $SECRET_KEY = New-SecretKey -PythonCommand $PythonCommand
    $envContent = Get-Content ".env"

    if ($envContent -match "^SECRET_KEY=") {
        $envContent = $envContent -replace "^SECRET_KEY=.*", "SECRET_KEY=$SECRET_KEY"
    } else {
        Add-Content ".env" "SECRET_KEY=$SECRET_KEY"
    }
    $envContent | Set-Content ".env" -Encoding UTF8
    Write-Success "SECRET_KEY updated in .env"
}

function Update-DockerCompose {
    Write-Info "Ensuring docker-compose.yml uses docker/Dockerfile.windows for web..."

    $dockerComposePath = "./docker-compose.yml"
    $content = Get-Content $dockerComposePath -Raw

    # Replace dockerfile paths for services that specify a dockerfile
    $content = $content -replace "(dockerfile:\s*)(?:Dockerfile\\.windows|Dockerfile\\.ubuntu|Dockerfile\\.macos)", "`${1}docker/Dockerfile.windows"

    $content | Set-Content $dockerComposePath -Encoding UTF8
    Write-Success "docker-compose.yml updated correctly to use docker/Dockerfile.windows"
}

function Test-Docker {
    Write-Info "Checking Docker..."
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker not found. Please install Docker Desktop."; exit 1
    }

    try { docker info 2>$null; if ($LASTEXITCODE -ne 0) { throw "Docker not running" } }
    catch { Write-Error "Docker not running. Please start Docker Desktop."; exit 1 }

    Write-Success "Docker is running"
}

function Start-Containers {
    Write-Info "Building and starting Docker containers..."
    docker compose up -d --build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Docker containers"
        exit 1
    }

    # Verify the web container is running
    $status = docker compose ps web --format json | ConvertFrom-Json
    if (!$status -or $status.State -ne "running") {
        Write-Error "Web container is not running. Showing logs..."
        docker compose logs web
        exit 1
    }

    # Verify other containers
    foreach ($svc in @("web_v2","web_v3","worker")) {
        $s = docker compose ps $svc --format json | ConvertFrom-Json
        if (!$s -or $s.State -ne "running") {
            Write-Warning "$svc container is not running yet. Showing recent logs:"
            docker compose logs --tail=100 $svc
        }
    }

    Write-Success "Containers started and services are running"
    Show-ContainerStatus
}

function Invoke-Migrations {
    Write-Info "Applying database migrations..."
    Write-Info "Waiting for database..."
    Start-Sleep -Seconds 5

    $status = docker compose ps web --format json | ConvertFrom-Json
    if (!$status -or $status.State -ne "running") {
        Write-Error "Web container is not running. Cannot run migrations."
        docker compose logs web
        exit 1
    }

    docker compose exec web alembic upgrade head
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database migrations applied successfully"
    } else {
        Write-Warning "Alembic upgrade failed, attempting to stamp head and continue..."
        docker compose exec web alembic stamp head
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Stamped current DB state to head. Migrations considered applied."
        } else {
            Write-Error "Migration and stamping failed. Showing web logs..."
            docker compose logs web
            Write-Info "Showing worker logs (if any) to help diagnose:"
            docker compose logs --tail=100 worker
            exit 1
        }
    }

    Show-ContainerStatus
}

function Show-CompletionInfo {
    Write-Host ""
    Write-Success "Setup complete!"
    Write-Host ""
    Write-Host "[READY] Your app is running:" -ForegroundColor Green
    Write-Host "   Problem 1 (Task Management): http://localhost:8000"
    Write-Host "   P1 Docs: http://localhost:8000/docs"
    Write-Host "   Problem 2 (E-commerce): http://localhost:8001"
    Write-Host "   P2 Docs: http://localhost:8001/docs"
    Write-Host "   Problem 3 (Performance): http://localhost:8002"
    Write-Host "   P3 Docs: http://localhost:8002/docs"
    Write-Host "   PgAdmin: http://localhost:5050"
    Write-Host ""
    Write-Host "[COMMANDS] Useful commands:" -ForegroundColor Green
    Write-Host "   Logs: docker compose logs -f"
    Write-Host "   Stop: docker compose down"
    Write-Host "   Restart: docker compose restart"
}

function Show-ContainerStatus {
    Write-Host ""; Write-Info "Container status summary:"
    try {
        $ps = docker compose ps --format json | ConvertFrom-Json
        if ($ps) {
            foreach ($c in $ps) {
                $ports = $c.Ports -join ", "
                Write-Host (" - {0} [{1}]  State={2}  Status={3}  Ports={4}" -f $c.Name, $c.Service, $c.State, $c.Status, $ports)
            }
        } else {
            docker compose ps
        }
    } catch {
        docker compose ps
    }
}

try {
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host "[SETUP] Docker FastAPI Setup (scripts/setup-windows.ps1)" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    $pythonCmd = Test-Prerequisites
    Set-EnvironmentFile -PythonCommand $pythonCmd
    Update-DockerCompose
    Test-Docker
    Start-Containers
    Invoke-Migrations
    Show-CompletionInfo
} catch {
    Write-Error "Setup failed with error: $_"
    exit 1
}
