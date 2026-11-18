<#
.SYNOPSIS
Lists AWS SSO session names from the shared config file.

.DESCRIPTION
Reads parsed AWS config data and returns the names of sections declared as `sso-session`. When requested, it filters the result to only sessions backed by an unexpired local AWS SSO cache token.

.PARAMETER Active
Returns only configured sessions whose `sso_start_url` is backed by an unexpired AWS SSO cache token.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.PARAMETER CachePath
The path to the AWS CLI SSO cache directory.

.EXAMPLE
PS> Get-AwsSsoSessionNames

Returns every configured AWS SSO session name.

.EXAMPLE
PS> Get-AwsSsoSessionNames -Active

Returns configured SSO sessions that currently have a valid cached token.
#>
function Get-AwsSsoSessionNames {
    [CmdletBinding()]
    param(
        [switch] $Active,
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache')
    )

    $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath

    if (-not $sections) {
        return @()
    }

    $sessionSections = @(
        $sections |
        Where-Object { $_.Type -eq 'sso-session' }
    )

    $sessionNames = @($sessionSections.Name)

    if (-not $Active) {
        return $sessionNames
    }

    Write-Verbose "Enumerating active AWS sso-sessions from '$ConfigPath'."

    $cacheSnapshot = Get-AwsSsoCacheSnapshot -CachePath $CachePath
    $validStartUrls = $cacheSnapshot.ValidStartUrls

    Write-Verbose "Found $($validStartUrls.Count) distinct active SSO start URL(s) in cache."

    foreach ($sessionSection in $sessionSections) {
        if ([string]::IsNullOrWhiteSpace($sessionSection.Properties['sso_start_url'])) {
            continue
        }

        $startUrl = $sessionSection.Properties['sso_start_url']
        if ($validStartUrls.Contains($startUrl)) {
            Write-Verbose "sso-session '$($sessionSection.Name)' has at least one unexpired cache token."
            $sessionSection.Name
        }
    }
}
