<#
.SYNOPSIS
Returns the AWS SSO cache token status for a profile.

.DESCRIPTION
Finds the AWS SSO session behind a profile, matches it to the local AWS CLI SSO cache, and returns the best matching cache token record.

.PARAMETER ProfileName
The AWS profile name to inspect. Defaults to the current `AWS_PROFILE` value.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.PARAMETER CachePath
The path to the AWS CLI SSO cache directory.

.EXAMPLE
PS> Get-AwsSsoCacheToken -ProfileName 'example-nonprod-admin'

Returns cache status details for the specified AWS profile.
#>
function Get-AwsSsoCacheToken {
    [CmdletBinding()]
    param(
        [Alias('Profile')]
        [string] $ProfileName = $env:AWS_PROFILE,
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache')
    )

    Write-Verbose "Checking SSO cache token for profile '$ProfileName'."

    $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
    if (-not $sections) {
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'config-missing'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        Write-Verbose 'No AWS profile was provided.'
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'no-profile'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    $profileSection = @(
        $sections |
        Where-Object { $_.Type -eq 'profile' -and $_.Name -eq $ProfileName }
    ) | Select-Object -First 1
    if (-not $profileSection) {
        Write-Verbose "Profile '$ProfileName' was not found in the AWS config."
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'profile-missing'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    $sessionName = $profileSection.Properties['sso_session']
    if ([string]::IsNullOrWhiteSpace($sessionName)) {
        Write-Verbose "Profile '$ProfileName' does not define sso_session."
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'session-missing'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    $sessionSection = @(
        $sections |
        Where-Object { $_.Type -eq 'sso-session' -and $_.Name -eq $sessionName }
    ) | Select-Object -First 1
    if (-not $sessionSection -or [string]::IsNullOrWhiteSpace($sessionSection.Properties['sso_start_url'])) {
        Write-Verbose "sso-session '$sessionName' is missing or has no sso_start_url."
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'starturl-missing'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    $startUrl = $sessionSection.Properties['sso_start_url']
    Write-Verbose "Looking for cache entries matching start URL '$startUrl'."
    $cacheSnapshot = Get-AwsSsoCacheSnapshot -CachePath $CachePath
    if (-not $cacheSnapshot.Files.Count) {
        return [pscustomobject]@{
            Profile = $ProfileName
            Status = 'cache-missing'
            CacheFile = $null
            ExpiresAt = $null
            SecondsRemaining = $null
        }
    }

    $matchingEntries = $cacheSnapshot.Entries | Where-Object { $_.StartUrl -eq $startUrl }

    $bestMatch = $matchingEntries | Sort-Object ExpiresAt -Descending | Select-Object -First 1
    if ($bestMatch) {
        Write-Verbose "Using cache file '$($bestMatch.CacheFile)' with status '$($bestMatch.Status)'."
        return $bestMatch
    }

    Write-Verbose "No matching cache token found for start URL '$startUrl'."
    [pscustomobject]@{
        Profile = $ProfileName
        Status = 'token-missing'
        CacheFile = $null
        ExpiresAt = $null
        SecondsRemaining = $null
    }
}
