Write-Host "Checking PostgreSQL container..." -ForegroundColor Cyan

# Ensure persistent volume exists
docker volume create postgres_data | Out-Null

# Check whether the container already exists
docker container inspect postgres 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    $status = docker inspect --format '{{.State.Status}}' postgres

    if ($status -eq "running") {
        Write-Host "PostgreSQL container is already running." -ForegroundColor Yellow
        Write-Host "Port: 5432"
        exit 0
    }

    Write-Host "PostgreSQL container exists but is stopped. Starting it..." -ForegroundColor Cyan

    docker start postgres

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to start PostgreSQL container." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "PostgreSQL container not found. Creating a new container..." -ForegroundColor Cyan

    docker run -d `
      --memory=2g `
      --hostname postgres `
      --name postgres `
      -p 5432:5432 `
      -e POSTGRES_USER=postgres `
      -e POSTGRES_PASSWORD=postgres `
      -v postgres_data:/var/lib/postgresql `
      postgres:latest

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create PostgreSQL container." -ForegroundColor Red
        exit 1
    }
}

Write-Host "PostgreSQL container started." -ForegroundColor Green
Write-Host "Host: localhost"
Write-Host "Port: 5432"
Write-Host "Database: postgres"