<#
.SYNOPSIS
Lists AWS profile names from the shared config file.

.DESCRIPTION
Returns AWS profile names, with optional filtering by profile name or SSO session. When requested, it can also return the associated SSO session per profile.

.PARAMETER ShowSsoSession
Returns profile objects that include the associated SSO session name instead of only profile names.

.PARAMETER ProfileName
Filters the returned profiles by name. Wildcards are supported, and plain text is treated as a prefix match. A plain-text value that matches no profiles throws an error.

.PARAMETER SsoSession
Filters the returned profiles to a specific AWS SSO session name.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> Get-AwsProfileNames -SsoSession 'example-sso'

Returns profile names associated with the specified SSO session.
#>
function Get-AwsProfileNames {
    [CmdletBinding()]
    param(
        [switch] $ShowSsoSession,
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
                $fakeBoundParameters.ConfigPath
            }
            else {
                Join-Path $HOME '.aws\config'
            }

            $profileParams = @{
                ConfigPath = $configPath
            }

            if ($fakeBoundParameters.ContainsKey('SsoSession')) {
                $profileParams.SsoSession = $fakeBoundParameters.SsoSession
            }

            Get-AwsProfileNames @profileParams |
                Where-Object { $_ -like "$wordToComplete*" } |
                Sort-Object -Unique
        })]
        [string] $ProfileName,
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

            $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
                $fakeBoundParameters.ConfigPath
            }
            else {
                Join-Path $HOME '.aws\config'
            }

            Get-AwsSsoSessionNames -ConfigPath $configPath |
                Where-Object { $_ -like "$wordToComplete*" } |
                Sort-Object -Unique
        })]
        [Alias('sso-session')]
        [string] $SsoSession,
        [string] $ConfigPath = (Join-Path $HOME '.aws\config')
    )

    Write-Verbose "Enumerating AWS profiles from '$ConfigPath'."

    $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
    if (-not $sections) {
        return @()
    }

    $results = @(
        $sections |
            Where-Object { $_.Type -eq 'profile' } |
            ForEach-Object {
                Write-Verbose "Found profile '$($_.Name)'."
                if ($_.Properties.ContainsKey('sso_session')) {
                    Write-Verbose "Profile '$($_.Name)' references sso-session '$($_.Properties['sso_session'])'."
                }

                [pscustomobject]@{
                    ProfileName = $_.Name
                    SsoSession = $_.Properties['sso_session']
                }
            }
    )

    if ($PSBoundParameters.ContainsKey('SsoSession')) {
        Write-Verbose "Filtering profiles to sso-session '$SsoSession'."
        $results = @($results | Where-Object { $_.SsoSession -eq $SsoSession })
    }

    if ($PSBoundParameters.ContainsKey('ProfileName')) {
        $usesWildcard = $ProfileName.IndexOfAny(@('*', '?')) -ge 0
        $profilePattern = if ($ProfileName.IndexOfAny(@('*', '?')) -ge 0) {
            $ProfileName
        }
        else {
            "$ProfileName*"
        }

        Write-Verbose "Filtering profiles to names like '$profilePattern'."
        $results = @($results | Where-Object { $_.ProfileName -like $profilePattern })

        if (-not $usesWildcard -and $results.Count -eq 0) {
            throw "No AWS profile names starting with '$ProfileName' were found in '$ConfigPath'."
        }
    }

    if ($ShowSsoSession) {
        Write-Verbose "Returning $($results.Count) profile/session mapping(s)."
        return $results
    }

    Write-Verbose "Returning $($results.Count) profile name(s)."
    $results.ProfileName
}

