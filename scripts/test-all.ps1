param(
    [switch]$Coverage
)

$ErrorActionPreference = "Stop"

function Write-Info { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Fail { param([string]$Message) Write-Host "[FAIL]  $Message" -ForegroundColor Red }

function Invoke-Pytest {
    param(
        [string]$Name,
        [string[]]$ExecArgs
    )
    Write-Info "Running $Name tests..."
    Write-Host "`n> docker compose exec $($ExecArgs -join ' ')`n" -ForegroundColor Yellow
    & docker compose exec @ExecArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Fail "$Name tests failed (exit $code)"
        return $false
    }
    Write-Ok "$Name tests passed"
    return $true
}

$allOk = $true

# Coverage flags
if ($Coverage) {
    $cov1 = " --cov=problems/problem_1/app"
    $cov2 = " --cov=problems/problem_2/app"
    $cov3 = " --cov=problems/problem_3/app"
} else {
    $cov1 = ""
    $cov2 = ""
    $cov3 = ""
}

# Problem 1
$args1 = @('-e', 'P1_BASE_URL=http://web:8000', '-e', 'POSTGRES_HOST=db', 'web', 'pytest', '-q', 'problems/problem_1/tests', "-s$cov1")
$ok = Invoke-Pytest -Name "Problem 1" -ExecArgs $args1
if (-not $ok) { $allOk = $false }

# Problem 2 (depends on Problem 1 auth)
$args2 = @('-e', 'P1_BASE_URL=http://web:8000', '-e', 'P2_BASE_URL=http://web_v2:8001', '-e', 'POSTGRES_HOST=db', 'web', 'pytest', '-q', 'problems/problem_2/tests', "-s$cov2")
$ok = Invoke-Pytest -Name "Problem 2" -ExecArgs $args2
if (-not $ok) { $allOk = $false }

# Problem 3 (run from web but via gateway proxy)
$args3 = @('-e', 'P3_API_BASE_URL=http://gateway/p3/api/p3', 'web', 'pytest', '-q', 'problems/problem_3/tests', "-s$cov3")
$ok = Invoke-Pytest -Name "Problem 3" -ExecArgs $args3
if (-not $ok) { $allOk = $false }

# Summarize logs
Write-Info "Summarizing test logs..."
docker compose exec web python tests/summarize_logs.py

if ($allOk) {
    Write-Ok "All problem tests passed"
    exit 0
} else {
    Write-Fail "One or more problem tests failed"
    exit 1
}
