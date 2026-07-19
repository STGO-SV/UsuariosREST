[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    [void](Get-Command aws -ErrorAction Stop)
    $awsRegion = [Environment]::GetEnvironmentVariable('AWS_REGION')
    $instanceId = [Environment]::GetEnvironmentVariable('RDS_INSTANCE_ID')
    if ([string]::IsNullOrWhiteSpace($awsRegion)) { throw 'AWS_REGION is not set.' }
    if ([string]::IsNullOrWhiteSpace($instanceId)) { throw 'RDS_INSTANCE_ID is not set.' }

    $json = & aws rds describe-db-instances --db-instance-identifier $instanceId --region $awsRegion --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Unable to read RDS status: $($json -join ' ')" }
    $database = ($json -join "`n" | ConvertFrom-Json).DBInstances[0]

    [pscustomobject]@{
        InstanceId          = $database.DBInstanceIdentifier
        Status              = $database.DBInstanceStatus
        Endpoint            = $database.Endpoint.Address
        Port                = $database.Endpoint.Port
        Engine              = $database.Engine
        EngineVersion       = $database.EngineVersion
        InstanceClass       = $database.DBInstanceClass
        AllocatedStorageGiB = $database.AllocatedStorage
        PubliclyAccessible  = $database.PubliclyAccessible
        SecurityGroups      = ($database.VpcSecurityGroups.VpcSecurityGroupId -join ', ')
        Database            = $(if ($database.DBName) { $database.DBName } else { 'municipalidad_la_florida (created by SQL script)' })
        Region              = $awsRegion
    } | Format-List
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
