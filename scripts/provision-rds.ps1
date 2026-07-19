[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$requiredVariables = @(
    'AWS_REGION',
    'RDS_INSTANCE_ID',
    'RDS_DB_NAME',
    'RDS_MASTER_USERNAME',
    'RDS_MASTER_PASSWORD',
    'RDS_INSTANCE_CLASS',
    'RDS_ALLOCATED_STORAGE',
    'RDS_ALLOWED_CIDR'
)
$expectedDatabase = 'municipalidad_la_florida'

function Get-RequiredEnvironmentVariable {
    param([Parameter(Mandatory)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable $Name is not set."
    }
    return $value
}

function Invoke-AwsJson {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $json = & aws @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI failed: $($json -join ' ')"
    }
    if ([string]::IsNullOrWhiteSpace(($json -join ''))) {
        return $null
    }
    return (($json -join "`n") | ConvertFrom-Json)
}

try {
    foreach ($variable in $requiredVariables) {
        [void](Get-RequiredEnvironmentVariable -Name $variable)
    }

    $awsRegion = Get-RequiredEnvironmentVariable 'AWS_REGION'
    $instanceId = Get-RequiredEnvironmentVariable 'RDS_INSTANCE_ID'
    $dbName = Get-RequiredEnvironmentVariable 'RDS_DB_NAME'
    $masterUsername = Get-RequiredEnvironmentVariable 'RDS_MASTER_USERNAME'
    $masterPassword = Get-RequiredEnvironmentVariable 'RDS_MASTER_PASSWORD'
    $instanceClass = Get-RequiredEnvironmentVariable 'RDS_INSTANCE_CLASS'
    $allocatedStorageText = Get-RequiredEnvironmentVariable 'RDS_ALLOCATED_STORAGE'
    $allowedCidr = Get-RequiredEnvironmentVariable 'RDS_ALLOWED_CIDR'
    $publicAccessText = [Environment]::GetEnvironmentVariable('RDS_PUBLICLY_ACCESSIBLE')
    if ([string]::IsNullOrWhiteSpace($publicAccessText)) { $publicAccessText = 'false' }

    if ($dbName -ne $expectedDatabase) {
        throw "RDS_DB_NAME must be '$expectedDatabase' to match the official EFT contract."
    }
    $allocatedStorage = 0
    if (-not [int]::TryParse($allocatedStorageText, [ref]$allocatedStorage) -or $allocatedStorage -lt 20) {
        throw 'RDS_ALLOCATED_STORAGE must be an integer of at least 20 GiB.'
    }
    $publiclyAccessible = $false
    if (-not [bool]::TryParse($publicAccessText, [ref]$publiclyAccessible)) {
        throw 'RDS_PUBLICLY_ACCESSIBLE must be true or false.'
    }
    if ($allowedCidr -notmatch '^(?:\d{1,3}\.){3}\d{1,3}/(?:3[0-2]|[12]?\d)$') {
        throw 'RDS_ALLOWED_CIDR must be a valid IPv4 CIDR, preferably the authorized public IP followed by /32.'
    }
    if ($masterPassword.Length -lt 8 -or $masterPassword.Length -gt 41 -or $masterPassword -match '[\s/@"]') {
        throw 'RDS_MASTER_PASSWORD must be 8-41 characters and cannot contain spaces, /, @, or double quotes.'
    }

    [void](Get-Command aws -ErrorAction Stop)
    Write-Host 'Validating AWS session...'
    [void](Invoke-AwsJson -Arguments @('sts', 'get-caller-identity', '--region', $awsRegion, '--output', 'json'))

    $existing = $null
    $describeOutput = & aws rds describe-db-instances --db-instance-identifier $instanceId --region $awsRegion --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $existing = ($describeOutput -join "`n" | ConvertFrom-Json).DBInstances[0]
    }
    elseif (($describeOutput -join ' ') -notmatch 'DBInstanceNotFound') {
        throw "Unable to inspect RDS instance: $($describeOutput -join ' ')"
    }

    if ($null -ne $existing) {
        if ($existing.Engine -ne 'mysql') {
            throw "Existing instance '$instanceId' uses engine '$($existing.Engine)', not MySQL. No changes were made."
        }
        Write-Host "RDS instance '$instanceId' already exists; it will not be overwritten."
    }
    else {
        Write-Host 'Locating the default VPC...'
        $vpcs = Invoke-AwsJson -Arguments @('ec2', 'describe-vpcs', '--filters', 'Name=is-default,Values=true', '--region', $awsRegion, '--output', 'json')
        $defaultVpc = @($vpcs.Vpcs)[0]
        if ($null -eq $defaultVpc) {
            throw 'No default VPC was found. This minimal script will not create or modify a VPC.'
        }

        $securityGroupName = "$instanceId-rds-sg"
        $groups = Invoke-AwsJson -Arguments @(
            'ec2', 'describe-security-groups',
            '--filters', "Name=vpc-id,Values=$($defaultVpc.VpcId)", "Name=group-name,Values=$securityGroupName",
            '--region', $awsRegion, '--output', 'json'
        )
        $securityGroup = @($groups.SecurityGroups)[0]
        if ($null -eq $securityGroup) {
            Write-Host "Creating security group '$securityGroupName' in the default VPC..."
            $createdGroup = Invoke-AwsJson -Arguments @(
                'ec2', 'create-security-group', '--group-name', $securityGroupName,
                '--description', 'Restricted MySQL access for UsuariosREST EFT evaluation',
                '--vpc-id', $defaultVpc.VpcId, '--region', $awsRegion, '--output', 'json'
            )
            $securityGroupId = $createdGroup.GroupId
            [void](Invoke-AwsJson -Arguments @(
                'ec2', 'create-tags', '--resources', $securityGroupId,
                '--tags', 'Key=Project,Value=UsuariosREST', 'Key=Purpose,Value=EFT-evaluation',
                '--region', $awsRegion, '--output', 'json'
            ))
        }
        else {
            $securityGroupId = $securityGroup.GroupId
            Write-Host "Reusing security group '$securityGroupName'."
        }

        $hasRule = $false
        $currentGroup = Invoke-AwsJson -Arguments @('ec2', 'describe-security-groups', '--group-ids', $securityGroupId, '--region', $awsRegion, '--output', 'json')
        foreach ($permission in @($currentGroup.SecurityGroups[0].IpPermissions)) {
            if ($permission.IpProtocol -eq 'tcp' -and $permission.FromPort -eq 3306 -and $permission.ToPort -eq 3306) {
                if (@($permission.IpRanges.CidrIp) -contains $allowedCidr) { $hasRule = $true }
            }
        }
        if (-not $hasRule) {
            Write-Host "Authorizing MySQL only from $allowedCidr..."
            [void](Invoke-AwsJson -Arguments @(
                'ec2', 'authorize-security-group-ingress', '--group-id', $securityGroupId,
                '--protocol', 'tcp', '--port', '3306', '--cidr', $allowedCidr,
                '--region', $awsRegion, '--output', 'json'
            ))
        }

        # RDS creates the official initial schema; 01-create-schema.sql remains safe to run because it uses IF NOT EXISTS.
        $request = @{
            DBInstanceIdentifier       = $instanceId
            DBInstanceClass            = $instanceClass
            Engine                     = 'mysql'
            EngineVersion              = '8.0'
            AllocatedStorage           = $allocatedStorage
            StorageType                = 'gp3'
            MasterUsername             = $masterUsername
            MasterUserPassword         = $masterPassword
            DBName                     = $dbName
            Port                       = 3306
            VpcSecurityGroupIds        = @($securityGroupId)
            PubliclyAccessible         = $publiclyAccessible
            MultiAZ                    = $false
            BackupRetentionPeriod      = 1
            AutoMinorVersionUpgrade    = $true
            EnablePerformanceInsights  = $false
            DeletionProtection         = $false
            CopyTagsToSnapshot         = $true
            Tags                       = @(
                @{ Key = 'Project'; Value = 'UsuariosREST' },
                @{ Key = 'Purpose'; Value = 'EFT-evaluation' }
            )
        }
        $requestPath = Join-Path ([System.IO.Path]::GetTempPath()) ("usuariosrest-rds-{0}.json" -f [guid]::NewGuid())
        try {
            $requestJson = $request | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($requestPath, $requestJson, [System.Text.UTF8Encoding]::new($false))
            $requestUri = 'file:///' + ($requestPath -replace '\\', '/')
            Write-Host "Creating minimal MySQL 8 RDS instance '$instanceId' (Single-AZ, $instanceClass, $allocatedStorage GiB gp3)..."
            $createOutput = & aws rds create-db-instance --cli-input-json $requestUri --region $awsRegion --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "RDS creation failed: $($createOutput -join ' ')"
            }
        }
        finally {
            if (Test-Path -LiteralPath $requestPath) {
                Remove-Item -LiteralPath $requestPath -Force
            }
            $masterPassword = $null
            $request = $null
            $requestJson = $null
        }
    }

    Write-Host 'Waiting for the RDS instance to become available...'
    & aws rds wait db-instance-available --db-instance-identifier $instanceId --region $awsRegion
    if ($LASTEXITCODE -ne 0) { throw 'RDS waiter failed before the instance became available.' }

    $final = Invoke-AwsJson -Arguments @('rds', 'describe-db-instances', '--db-instance-identifier', $instanceId, '--region', $awsRegion, '--output', 'json')
    $database = $final.DBInstances[0]
    Write-Host 'RDS instance is available.'
    Write-Host "Endpoint: $($database.Endpoint.Address)"
    Write-Host "Port: $($database.Endpoint.Port)"
    Write-Host "Next: set DB_HOST to this endpoint and run scripts/configure-rds-database.ps1."
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
