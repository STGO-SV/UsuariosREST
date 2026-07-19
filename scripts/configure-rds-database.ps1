[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$expectedDatabase = 'municipalidad_la_florida'
$requiredVariables = @('DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USERNAME', 'DB_PASSWORD')

function Get-RequiredEnvironmentVariable {
    param([Parameter(Mandatory)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable $Name is not set."
    }
    return $value
}

function Invoke-MySqlFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SelectDatabase
    )

    Write-Host "Executing $([System.IO.Path]::GetFileName($Path))..."
    $arguments = @(
        '--protocol=TCP',
        "--host=$script:dbHost",
        "--port=$script:dbPort",
        "--user=$script:dbUsername",
        '--default-character-set=utf8mb4',
        '--connect-timeout=10'
    )
    if ($SelectDatabase) {
        $arguments += "--database=$script:dbName"
    }

    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | & $script:mysqlCommand @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "mysql failed while executing $([System.IO.Path]::GetFileName($Path)) (exit code $LASTEXITCODE)."
    }
}

try {
    foreach ($variable in $requiredVariables) {
        [void](Get-RequiredEnvironmentVariable -Name $variable)
    }

    $script:dbHost = Get-RequiredEnvironmentVariable -Name 'DB_HOST'
    $script:dbPort = Get-RequiredEnvironmentVariable -Name 'DB_PORT'
    $script:dbName = Get-RequiredEnvironmentVariable -Name 'DB_NAME'
    $script:dbUsername = Get-RequiredEnvironmentVariable -Name 'DB_USERNAME'
    $dbPassword = Get-RequiredEnvironmentVariable -Name 'DB_PASSWORD'

    $parsedPort = 0
    if (-not [int]::TryParse($script:dbPort, [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
        throw 'DB_PORT must be an integer between 1 and 65535.'
    }
    if ($script:dbName -ne $expectedDatabase) {
        throw "DB_NAME must be '$expectedDatabase' because the official EFT scripts define that schema."
    }

    $script:mysqlCommand = (Get-Command mysql -ErrorAction Stop).Source
    Write-Host "mysql client found: $script:mysqlCommand"
    Write-Host "Testing TCP connectivity to $script:dbHost`:$parsedPort..."
    $tcpResult = Test-NetConnection -ComputerName $script:dbHost -Port $parsedPort -WarningAction SilentlyContinue
    if (-not $tcpResult.TcpTestSucceeded) {
        throw "TCP connection to $script:dbHost`:$parsedPort failed."
    }

    $projectRoot = Split-Path -Parent $PSScriptRoot
    $sqlDirectory = Join-Path $projectRoot 'database'
    $sqlFiles = @(
        (Join-Path $sqlDirectory '01-create-schema.sql'),
        (Join-Path $sqlDirectory '02-seed-data.sql'),
        (Join-Path $sqlDirectory '03-verify-database.sql')
    )
    foreach ($sqlFile in $sqlFiles) {
        if (-not (Test-Path -LiteralPath $sqlFile -PathType Leaf)) {
            throw "Required SQL file not found: $sqlFile"
        }
    }

    $previousMySqlPassword = [Environment]::GetEnvironmentVariable('MYSQL_PWD', 'Process')
    $env:MYSQL_PWD = $dbPassword
    try {
        Invoke-MySqlFile -Path $sqlFiles[0]
        Invoke-MySqlFile -Path $sqlFiles[1] -SelectDatabase
        Invoke-MySqlFile -Path $sqlFiles[2] -SelectDatabase
    }
    finally {
        if ($null -eq $previousMySqlPassword) {
            Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
        }
        else {
            $env:MYSQL_PWD = $previousMySqlPassword
        }
        $dbPassword = $null
    }

    Write-Host 'RDS database configuration and verification completed successfully.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
