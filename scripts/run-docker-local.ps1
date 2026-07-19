[CmdletBinding()]
param(
    [int]$HostPort = 8080
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $projectRoot '.env.rds'
$imageName = 'usuarios-rest:local'
$containerName = 'usuarios-rest-local'
$requiredVariables = @('DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USERNAME', 'DB_PASSWORD')

try {
    [void](Get-Command docker -ErrorAction Stop)
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Engine is not available.' }
    if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) { throw '.env.rds was not found.' }

    $presentNames = Get-Content -Encoding UTF8 -LiteralPath $environmentFile |
        Where-Object { $_ -match '^\s*[^#=]+=' } |
        ForEach-Object { (($_ -split '=', 2)[0]).Trim() }
    foreach ($required in $requiredVariables) {
        if ($required -notin $presentNames) { throw "Required key $required is missing from .env.rds." }
    }

    & docker image inspect $imageName *> $null
    if ($LASTEXITCODE -ne 0) { throw "Docker image $imageName does not exist. Run build-docker-image.ps1 first." }

    $existing = & docker ps -a --filter "name=^/$containerName$" --format '{{.Names}}'
    if ($existing -eq $containerName) {
        Write-Host "Replacing existing project container $containerName..."
        & docker rm --force $containerName *> $null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to remove the existing project container.' }
    }

    Write-Host "Starting $containerName on local port $HostPort..."
    $containerId = & docker run --detach --name $containerName --restart no --env-file $environmentFile --publish "${HostPort}:8080" $imageName
    if ($LASTEXITCODE -ne 0) { throw 'Docker run failed.' }

    $deadline = (Get-Date).AddMinutes(2)
    do {
        Start-Sleep -Seconds 3
        $running = & docker inspect $containerName --format '{{.State.Running}}' 2>$null
        if ($running -ne 'true') { throw 'Container stopped before becoming ready.' }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$HostPort/" -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Host "Container is ready (HTTP 200)."
                Write-Host "Container id: $($containerId.Substring(0, 12))"
                exit 0
            }
        }
        catch {
            # Application is still starting.
        }
    } while ((Get-Date) -lt $deadline)

    throw 'Container did not become ready within two minutes.'
}
catch {
    Write-Error $_.Exception.Message
    try { & docker logs --tail 80 $containerName 2>&1 | Select-String -NotMatch 'password|jdbc:mysql' }
    catch { }
    exit 1
}
