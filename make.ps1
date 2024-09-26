# PowerShell equivalent of Makefile

# OS detection
$isWindows = $PSVersionTable.PSVersion.Major -ge 5 -and $PSVersionTable.OS -match 'Windows'
$isMacOS = $IsMacOS
$isLinux = $IsLinux

# Configuration variables
$VERSION = (Select-String -Path "pyproject.toml" -Pattern '^version\s*=\s*"(.+)"').Matches.Groups[1].Value
$DOCKERFILE = "docker/build_and_push.Dockerfile"
$DOCKERFILE_BACKEND = "docker/build_and_push_backend.Dockerfile"
$DOCKERFILE_FRONTEND = "docker/frontend/build_and_push_frontend.Dockerfile"
$DOCKER_COMPOSE = "docker_example/docker-compose.yml"
$PYTHON_REQUIRED = (Select-String -Path "pyproject.toml" -Pattern '^python\s*=\s*"(.+)"').Matches.Groups[1].Value

# Default values
$hostAddress = "0.0.0.0"
$port = 7860
$env = ".env"
$open_browser = $true
$path = "src/backend/base/langflow/frontend"
$workers = 1
$async = $true

# Function to run commands based on OS
function Invoke-OSCommand {
    param (
        [string]$WindowsCommand,
        [string]$UnixCommand
    )
    if ($isWindows) {
        Invoke-Expression $WindowsCommand
    } else {
        bash -c $UnixCommand
    }
}

# Utility functions
function Install-Backend {
    Write-Host "Installing backend dependencies"
    Invoke-OSCommand -WindowsCommand "cd src/backend/base; uv sync; cd ..\..\..; uv sync" -UnixCommand "cd src/backend/base && uv sync && cd ../../../ && uv sync"
}

function Install-Frontend {
    Write-Host "Installing frontend dependencies"
    Invoke-OSCommand -WindowsCommand "cd src/frontend; npm install" -UnixCommand "cd src/frontend && npm install"
}

function Build-Frontend {
    Write-Host "Building frontend static files"
    Invoke-OSCommand -WindowsCommand "cd src/frontend; npm run build; cd ..\..; Remove-Item -Recurse -Force src/backend/base/langflow/frontend; Copy-Item -Recurse src/frontend/build src/backend/base/langflow/frontend" -UnixCommand "cd src/frontend && CI='' npm run build && cd ../.. && rm -rf src/backend/base/langflow/frontend && cp -r src/frontend/build src/backend/base/langflow/frontend"
}

# Main functions
function Initialize-Project {
    Install-Backend
    Install-Frontend
    Build-Frontend
    Write-Host "All requirements are installed."
    python -m langflow run
}

function Start-Backend {
    $envFile = if (Test-Path $env) { $env } else { ".env" }
    $command = ".\venv\Scripts\activate; python -m uvicorn --factory langflow.main:create_app --host $hostAddress --port $port --env-file $envFile --loop asyncio"
    if ($workers -eq 1) {
        $command += " --reload"
    }
    if ($workers -gt 1) {
        $command += " --workers $workers"
    }
    Invoke-Expression $command
}

function Start-Frontend {
    Invoke-OSCommand -WindowsCommand "cd src/frontend; npm start" -UnixCommand "cd src/frontend && npm start"
}

# Main script logic
switch ($args[0]) {
    "init" { Initialize-Project }
    "backend" { Start-Backend }
    "frontend" { Start-Frontend }
    "build" { Build-Frontend }
    default { Write-Host "Usage: ./make.ps1 [init|backend|frontend|build]" }
}