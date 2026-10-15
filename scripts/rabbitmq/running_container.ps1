# Write-Host "Starting Rabbitmq container....."
# docker volume create rabbitmq_data | Out-Null
# docker run -d `
#   --memory=2g `
#   --hostname my-rabbit `
#   --name rabbitmq `
#   -p 5672:5672 `
#   -p 15672:15672 `
#   -v rabbitmq_data:/var/lib/rabbitmq `
#   rabbitmq:management
# Write-Host "RabbitMQ container started. AMQP: 5672, Management UI: http://localhost:15672"
Write-Host "Checking RabbitMQ container..." -ForegroundColor Cyan

# Ensure persistent volume exists
docker volume create rabbitmq_data | Out-Null

# Check whether the container already exists
docker container inspect rabbitmq 2>$null | Out-Null

if ($LASTEXITCODE -eq 0) {
    # Container exists; check whether it is running
    $status = docker inspect --format '{{.State.Status}}' rabbitmq

    if ($status -eq "running") {
        Write-Host "RabbitMQ container is already running." -ForegroundColor Yellow
        Write-Host "AMQP: localhost:5672"
        Write-Host "Management UI: http://localhost:15672"
        exit 0
    }

    # Container exists but is stopped; start it again
    Write-Host "RabbitMQ container exists but is stopped. Starting it..." -ForegroundColor Cyan
    docker start rabbitmq

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to start RabbitMQ container." -ForegroundColor Red
        exit 1
    }
}
else {
    # Container does not exist; create it
    Write-Host "RabbitMQ container not found. Creating a new container..." -ForegroundColor Cyan

    docker run -d `
      --memory=2g `
      --hostname my-rabbit `
      --name rabbitmq `
      -p 5672:5672 `
      -p 15672:15672 `
      -v rabbitmq_data:/var/lib/rabbitmq `
      rabbitmq:management

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create RabbitMQ container." -ForegroundColor Red
        exit 1
    }
}

Write-Host "RabbitMQ container started." -ForegroundColor Green
Write-Host "AMQP: localhost:5672"
Write-Host "Management UI: http://localhost:15672"