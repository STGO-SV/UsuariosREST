[CmdletBinding()]
param(
    [switch]$RemoveImage
)

$ErrorActionPreference = 'Stop'
$containerName = 'usuarios-rest-local'
$imageName = 'usuarios-rest:local'

try {
    [void](Get-Command docker -ErrorAction Stop)
    $existing = & docker ps -a --filter "name=^/$containerName$" --format '{{.Names}}'
    if ($existing -eq $containerName) {
        Write-Host "Stopping and removing project container $containerName..."
        & docker rm --force $containerName *> $null
        if ($LASTEXITCODE -ne 0) { throw 'Unable to remove the project container.' }
    }
    else {
        Write-Host 'Project container does not exist.'
    }

    if ($RemoveImage) {
        & docker image inspect $imageName *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Removing project image $imageName..."
            & docker image rm $imageName *> $null
            if ($LASTEXITCODE -ne 0) { throw 'Unable to remove the project image.' }
        }
    }
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
