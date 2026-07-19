[CmdletBinding()]
param(
    [int]$HostPort = 8080
)

$ErrorActionPreference = 'Stop'
$baseUrl = "http://localhost:$HostPort"
$usersUrl = "$baseUrl/user"
$createdId = $null

function Invoke-JsonRequest {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body
    )
    $parameters = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true; TimeoutSec = 20 }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json; charset=utf-8'
        $parameters.Body = $Body | ConvertTo-Json
    }
    $response = Invoke-WebRequest @parameters
    $json = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json }
    return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Body = $json }
}

try {
    $initial = Invoke-JsonRequest -Method GET -Uri $usersUrl
    if ($initial.StatusCode -ne 200 -or @($initial.Body).Count -ne 10) { throw 'Initial GET did not return exactly ten users.' }
    Write-Host 'GET /user: HTTP 200, ten official records.'

    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
    $email = "eft-docker-$suffix@example.test"
    $created = Invoke-JsonRequest -Method POST -Uri $usersUrl -Body @{ firstName='Docker'; lastName='Temporal'; email=$email }
    if ($created.StatusCode -ne 200 -or [long]$created.Body.id -le 0) { throw 'POST did not create the temporary user.' }
    $createdId = [long]$created.Body.id
    Write-Host "POST /user: HTTP $($created.StatusCode), temporary user created."

    $fetched = Invoke-JsonRequest -Method GET -Uri "$usersUrl/$createdId"
    if ($fetched.StatusCode -ne 200 -or $fetched.Body.email -ne $email) { throw 'GET did not return the temporary user.' }
    Write-Host "GET /user/{id}: HTTP $($fetched.StatusCode), temporary user found."

    $updated = Invoke-JsonRequest -Method PUT -Uri "$usersUrl/$createdId" -Body @{ firstName='DockerActualizado'; lastName='Temporal'; email=$email }
    if ($updated.StatusCode -ne 200 -or $updated.Body.firstName -ne 'DockerActualizado') { throw 'PUT did not update the user.' }
    Write-Host "PUT /user/{id}: HTTP $($updated.StatusCode), user updated."

    $confirmed = Invoke-JsonRequest -Method GET -Uri "$usersUrl/$createdId"
    if ($confirmed.StatusCode -ne 200 -or $confirmed.Body.firstName -ne 'DockerActualizado') { throw 'GET did not confirm the update.' }
    Write-Host "GET updated /user/{id}: HTTP $($confirmed.StatusCode), update confirmed."

    $deleted = Invoke-JsonRequest -Method DELETE -Uri "$usersUrl/$createdId"
    if ($deleted.StatusCode -ne 200) { throw 'DELETE did not return HTTP 200.' }
    Write-Host "DELETE /user/{id}: HTTP $($deleted.StatusCode)."

    try {
        [void](Invoke-JsonRequest -Method GET -Uri "$usersUrl/$createdId")
        throw 'Final GET unexpectedly found the deleted user.'
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($statusCode -notin @(400, 404)) { throw }
        Write-Host "Final GET /user/{id}: HTTP $statusCode, deletion confirmed."
    }
    $createdId = $null

    $final = Invoke-JsonRequest -Method GET -Uri $usersUrl
    if ($final.StatusCode -ne 200 -or @($final.Body).Count -ne 10) { throw 'Final GET did not preserve the ten official records.' }
    Write-Host 'Final GET /user: HTTP 200, ten official records remain.'
    Write-Host 'Docker deployment CRUD verification completed successfully.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    if ($null -ne $createdId) {
        try { [void](Invoke-JsonRequest -Method DELETE -Uri "$usersUrl/$createdId") }
        catch { Write-Warning 'Temporary user cleanup failed; verify it manually.' }
    }
    exit 1
}
