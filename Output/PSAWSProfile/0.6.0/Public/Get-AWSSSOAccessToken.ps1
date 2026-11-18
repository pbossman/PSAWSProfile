<#
.SYNOPSIS
Retrieves an active AWS SSO access token from the local cache.

.DESCRIPTION
Finds an unexpired AWS SSO access token in the cache and stores it in the module session state.
Use PassThru to return the token.

.PARAMETER ConfigPath
Reserved for compatibility. The AWS config file path is not currently used.

.PARAMETER CachePath
The path to the AWS CLI SSO cache directory.

.PARAMETER PassThru
Returns the access token instead of only storing it in the module session state.

.EXAMPLE
PS> Get-AWSSSOAccessToken

Stores an active cached AWS SSO access token in the module session state.
#>
function Get-AWSSSOAccessToken {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache'),
        [switch] $PassThru
    )

    Write-Verbose "Getting SSO access token from '$CachePath'."

    $accessToken = Get-ChildItem $CachePath -Filter *.json |
        Get-Content -Raw |
        ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.accessToken } |
        Where-Object { $_.startUrl } |
        Where-Object { $_.expiresAt -gt (Get-Date) } |
        Select-Object -ExpandProperty AccessToken

    $script:AccessToken = $accessToken
    if ($PassThru) {
        return $accessToken
    }

}
