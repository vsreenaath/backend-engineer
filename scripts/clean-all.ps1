param(
    [switch]$Force,
    [switch]$RemoveImages
)

function Write-Info { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Fail { param([string]$Message) Write-Host "[FAIL]  $Message" -ForegroundColor Red }

if (-not $Force) {
    Write-Info "This will stop containers and remove project volumes (destructive). Use -Force to skip this prompt."
    $confirm = Read-Host "Proceed? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Aborted by user."
        exit 0
    }
}

Write-Info "Stopping and removing containers, networks, and volumes for this compose project..."
& docker compose down -v --remove-orphans
if ($LASTEXITCODE -ne 0) { Write-Fail "docker compose down failed"; exit 1 }

if ($RemoveImages) {
    Write-Info "Removing local images built by this project (optional)..."
    & docker compose down -v --rmi local --remove-orphans
    if ($LASTEXITCODE -ne 0) { Write-Fail "image removal step failed"; exit 1 }
}

Write-Ok "Cleanup completed."
