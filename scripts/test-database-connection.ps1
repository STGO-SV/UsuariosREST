[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$requiredVariables = @('DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USERNAME', 'DB_PASSWORD')

function Get-RequiredEnvironmentVariable {
    param([Parameter(Mandatory)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable $Name is not set."
    }
    return $value
}

try {
    foreach ($variable in $requiredVariables) {
        [void](Get-RequiredEnvironmentVariable -Name $variable)
    }

    $dbHost = Get-RequiredEnvironmentVariable -Name 'DB_HOST'
    $dbPort = Get-RequiredEnvironmentVariable -Name 'DB_PORT'
    $dbName = Get-RequiredEnvironmentVariable -Name 'DB_NAME'
    $dbUsername = Get-RequiredEnvironmentVariable -Name 'DB_USERNAME'
    $dbPassword = Get-RequiredEnvironmentVariable -Name 'DB_PASSWORD'

    $parsedPort = 0
    if (-not [int]::TryParse($dbPort, [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
        throw 'DB_PORT must be an integer between 1 and 65535.'
    }

    Write-Host "Resolving DNS for $dbHost..."
    $dnsResult = Resolve-DnsName -Name $dbHost -ErrorAction Stop | Where-Object { $_.IPAddress }
    if (-not $dnsResult) {
        throw "DNS resolution returned no IP address for $dbHost."
    }
    Write-Host "DNS resolved: $($dnsResult.IPAddress -join ', ')"

    Write-Host "Testing TCP connectivity to $dbHost`:$parsedPort..."
    $tcpResult = Test-NetConnection -ComputerName $dbHost -Port $parsedPort -WarningAction SilentlyContinue
    if (-not $tcpResult.TcpTestSucceeded) {
        throw "TCP connection to $dbHost`:$parsedPort failed."
    }

    $mysqlCommand = (Get-Command mysql -ErrorAction Stop).Source
    $query = "SELECT CONCAT('schema=', DATABASE()); SELECT CONCAT('users_table=', COUNT(*)) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'users'; SELECT CONCAT('user_count=', COUNT(*)) FROM users;"
    $arguments = @(
        '--protocol=TCP',
        "--host=$dbHost",
        "--port=$parsedPort",
        "--user=$dbUsername",
        "--database=$dbName",
        '--default-character-set=utf8mb4',
        '--connect-timeout=10',
        '--batch',
        '--skip-column-names',
        "--execute=$query"
    )

    $previousMySqlPassword = [Environment]::GetEnvironmentVariable('MYSQL_PWD', 'Process')
    $env:MYSQL_PWD = $dbPassword
    try {
        & $mysqlCommand @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "MySQL authentication or database verification failed (exit code $LASTEXITCODE)."
        }
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

    Write-Host 'Database connection verification completed successfully.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
