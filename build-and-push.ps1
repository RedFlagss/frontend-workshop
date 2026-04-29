param(
    [string]$Version = "latest",
    [string]$OldTag = ""
)

$USERNAME = "dischargedrobo"
$IMAGE_NAME = "frontend-workshop"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "Building image ${USERNAME}/${IMAGE_NAME}:${Version}"

# Загружаем переменные из docker.env файла
if (Test-Path "docker.env") {
    Get-Content "docker.env" | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            $name = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
} else {
    Write-Error "docker.env file not found!"
    exit 1
}

# Если собираем latest, переименовываем старый образ
if ($Version -eq "latest") {
    $oldImageExists = docker image inspect "${USERNAME}/${IMAGE_NAME}:latest" 2>$null
    if ($LASTEXITCODE -eq 0) {
        # Используем кастомный тег или генерируем автоматический
        if ($OldTag) {
            $newOldTag = $OldTag
        } else {
            $newOldTag = "old_${TIMESTAMP}"
        }
        Write-Host "Renaming old latest image to ${USERNAME}/${IMAGE_NAME}:${newOldTag}"
        docker tag "${USERNAME}/${IMAGE_NAME}:latest" "${USERNAME}/${IMAGE_NAME}:${newOldTag}"
    }
}

# Сборка образа
docker build `
    --build-arg NEXT_PUBLIC_API_URL="$env:NEXT_PUBLIC_API_URL" `
    --build-arg NEXT_PUBLIC_AUTH_SERVICE_URL_V1="$env:NEXT_PUBLIC_AUTH_SERVICE_URL_V1" `
    --build-arg NEXT_PUBLIC_AUTH_URL_V1="$env:NEXT_PUBLIC_AUTH_URL_V1" `
    --build-arg NEXT_PUBLIC_CLIENT_URL_V1="$env:NEXT_PUBLIC_CLIENT_URL_V1" `
    --build-arg NEXT_PUBLIC_API_FF_SERVICE_URL_V1="$env:NEXT_PUBLIC_API_FF_SERVICE_URL_V1" `
    --build-arg NEXT_PUBLIC_API_ORGANIZATIONS_URL_V1="$env:NEXT_PUBLIC_API_ORGANIZATIONS_URL_V1" `
    --build-arg API_GATEWAY_URL="$env:API_GATEWAY_URL" `
    --build-arg API_FF_SERVICE_URL_V1="$env:API_FF_SERVICE_URL_V1" `
    --build-arg API_AUTH_SERVICE_URL_V1="$env:API_AUTH_SERVICE_URL_V1" `
    --build-arg API_FF_ORGANIZATIONS_URL_V1="$env:API_FF_ORGANIZATIONS_URL_V1" `
    --build-arg API_AUTH_CLIENT_URL_V1="$env:API_AUTH_CLIENT_URL_V1" `
    -t "${USERNAME}/${IMAGE_NAME}:${Version}" .

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Pushing to Docker Hub..."
    docker push "${USERNAME}/${IMAGE_NAME}:${Version}"
    
    # Если собирали latest, пушим и старый образ
    if ($Version -eq "latest") {
        $newOldTag = if ($OldTag) { $OldTag } else { "old_${TIMESTAMP}" }
        $oldImageExists = docker image inspect "${USERNAME}/${IMAGE_NAME}:${newOldTag}" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Pushing old image backup..."
            docker push "${USERNAME}/${IMAGE_NAME}:${newOldTag}"
        }
    }
    
    Write-Host "Done!"
} else {
    Write-Error "Build failed!"
    exit 1
}