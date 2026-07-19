[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$imageName = 'usuarios-rest:local'

try {
    [void](Get-Command docker -ErrorAction Stop)
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Engine is not available.' }

    Push-Location $projectRoot
    try {
        Write-Host 'Building and testing the Maven WAR...'
        & .\mvnw.cmd clean package
        if ($LASTEXITCODE -ne 0) { throw "Maven package failed with exit code $LASTEXITCODE." }
        $artifact = Join-Path $projectRoot 'target\usuariosBuild.war'
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw 'Expected WAR was not generated.' }

        Write-Host "Building Docker image $imageName..."
        & docker build --pull --tag $imageName .
        if ($LASTEXITCODE -ne 0) { throw "Docker build failed with exit code $LASTEXITCODE." }

        $imageSize = & docker image inspect $imageName --format '{{.Size}}'
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the built image.' }
        Write-Host "Docker image built successfully. Size: $imageSize bytes."
    }
    finally {
        Pop-Location
    }
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
