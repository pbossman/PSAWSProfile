<#
.SYNOPSIS
Returns a named section from the AWS shared config file.

.DESCRIPTION
Looks up a section in the AWS shared config file and returns its key-value pairs as a PowerShell object.

.PARAMETER Name
The AWS config section name or full header text to retrieve.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> Get-AwsConfigSection -Name 'example-nonprod-admin'

Returns the settings stored under the specified profile section.
#>
function Get-AwsConfigSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [ValidateSet('profile','sso-session','default')]
        [string] $Type = 'profile',
        [string] $ConfigPath = (Join-Path $HOME '.aws\config')
    )

    Write-Verbose "Reading AWS config section '$Type $Name' from '$ConfigPath'."

    $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
    if (-not $sections) {
        Write-Verbose "No sections found in '$ConfigPath'."
        return $null
    }

    $section = @(
        $sections |
        Where-Object { $_.Type -eq $Type -and $_.Name -eq $Name }
    ) | Select-Object -First 1

    if (-not $section) {
        Write-Verbose "Section '$Type $Name' not found in '$ConfigPath'."
        return $null
    }

    Write-Verbose "Found section '$Type $Name' with $($section.Properties.Count) property/properties."
    $section
}
