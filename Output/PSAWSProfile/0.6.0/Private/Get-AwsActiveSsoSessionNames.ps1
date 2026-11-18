<#
.SYNOPSIS
Lists AWS SSO sessions that currently have an unexpired cache token.

.DESCRIPTION
Compatibility wrapper for `Get-AwsSsoSessionNames -Active`.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.PARAMETER CachePath
The path to the AWS CLI SSO cache directory.

.EXAMPLE
PS> Get-AwsActiveSsoSessionNames

Returns configured SSO sessions that currently have a valid cached token.
#>
function Get-AwsActiveSsoSessionNames {
    [CmdletBinding()]
    param(
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache')
    )

    $params = @{
        Active = $true
        ConfigPath = $ConfigPath
        CachePath = $CachePath
    }

    Get-AwsSsoSessionNames @params
}
