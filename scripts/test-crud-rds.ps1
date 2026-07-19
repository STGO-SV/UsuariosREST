[CmdletBinding()]
param(
    [string]$BaseUrl = $env:API_BASE_URL
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($BaseUrl)) { $BaseUrl = 'http://localhost:8080' }
$userEndpoint = "$($BaseUrl.TrimEnd('/'))/user"
$createdId = $null

function Invoke-ApiRequest {
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body
    )

    $parameters = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json; charset=utf-8'
        $parameters.Body = $Body | ConvertTo-Json
    }
    return Invoke-RestMethod @parameters
}

try {
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
    $email = "eft-rds-$suffix@example.test"
    $created = Invoke-ApiRequest -Method POST -Uri $userEndpoint -Body @{
        firstName = 'Temporal'
        lastName = 'EFT'
        email = $email
    }
    $createdId = [long]$created.id
    if ($createdId -le 0 -or $created.email -ne $email) { throw 'POST did not return the expected created user.' }
    Write-Host "POST: OK (temporary id $createdId)"

    $fetched = Invoke-ApiRequest -Method GET -Uri "$userEndpoint/$createdId"
    if ($fetched.id -ne $createdId -or $fetched.email -ne $email) { throw 'GET did not return the created user.' }
    Write-Host 'GET: OK'

    $updated = Invoke-ApiRequest -Method PUT -Uri "$userEndpoint/$createdId" -Body @{
        firstName = 'TemporalActualizado'
        lastName = 'EFT'
        email = $email
    }
    if ($updated.firstName -ne 'TemporalActualizado') { throw 'PUT did not return the updated firstName.' }
    Write-Host 'PUT: OK'

    [void](Invoke-ApiRequest -Method DELETE -Uri "$userEndpoint/$createdId")
    Write-Host 'DELETE: OK'

    try {
        [void](Invoke-ApiRequest -Method GET -Uri "$userEndpoint/$createdId")
        throw 'Final GET unexpectedly found the deleted user.'
    }
    catch {
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($statusCode -notin @(400, 404)) { throw }
    }
    $createdId = $null
    Write-Host 'Final GET: OK (user no longer exists)'
    Write-Host 'RDS CRUD verification completed successfully.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    if ($null -ne $createdId) {
        try {
            [void](Invoke-ApiRequest -Method DELETE -Uri "$userEndpoint/$createdId")
            Write-Warning "Temporary user $createdId was removed during cleanup."
        }
        catch {
            Write-Warning "Could not remove temporary user $createdId; manual cleanup may be required."
        }
    }
    exit 1
}
