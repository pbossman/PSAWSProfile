<#
.SYNOPSIS
Tests whether an AWS SSO-backed profile currently has a valid cached token.

.DESCRIPTION
Evaluates the local AWS SSO cache for the target profile and returns either a Boolean result or a detailed status object.

.PARAMETER ProfileName
The AWS profile name to test. Defaults to the current `AWS_PROFILE` value. If an explicit profile name is supplied and it is not found in the AWS config, the command throws an error.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.PARAMETER PassThru
Returns a detailed status object instead of only a Boolean value.

.EXAMPLE
PS> Test-AwsSsoProfile -ProfileName 'example-nonprod-admin' -PassThru

Returns detailed validity and cache status for the specified profile.
#>
function Test-AwsSsoProfile {
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
                $fakeBoundParameters.ConfigPath
            }
            else {
                Join-Path $HOME '.aws\config'
            }

            Get-AwsProfileNames -ConfigPath $configPath -ProfileName "$wordToComplete*" |
                Sort-Object -Unique
        })]
        [Alias('Profile')]
        [string] $ProfileName = $env:AWS_PROFILE,
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [switch] $PassThru
    )

    Write-Verbose "Testing AWS SSO profile '$ProfileName'."

    if (($PSBoundParameters.ContainsKey('ProfileName') -or $PSBoundParameters.ContainsKey('Profile')) -and -not [string]::IsNullOrWhiteSpace($ProfileName)) {
        $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
        $profileSection = @(
            $sections |
            Where-Object { $_.Type -eq 'profile' -and $_.Name -eq $ProfileName }
        ) | Select-Object -First 1
        if (-not $profileSection) {
            throw "AWS profile '$ProfileName' was not found in '$ConfigPath'."
        }
    }

    $token = Get-AwsSsoCacheToken -ProfileName $ProfileName -ConfigPath $ConfigPath
    $result = [pscustomobject]@{
        Profile = $ProfileName
        IsValid = $token.Status -eq 'valid'
        Status = $token.Status
        CheckedAt = Get-Date
        CacheFile = $token.CacheFile
        ExpiresAt = $token.ExpiresAt
        SecondsRemaining = $token.SecondsRemaining
    }

    Write-Verbose "Profile '$ProfileName' evaluated to status '$($result.Status)'."

    if ($PassThru) {
        $result
        return
    }

    $result.IsValid
}
