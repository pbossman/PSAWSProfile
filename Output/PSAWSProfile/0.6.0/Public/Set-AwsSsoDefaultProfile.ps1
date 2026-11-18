<#
.SYNOPSIS
Sets the current AWS profile after validating its SSO session.

.DESCRIPTION
Validates that the target profile exists, is backed by an AWS SSO session, and that the session currently has an active cached token before setting `AWS_PROFILE`.

.PARAMETER ProfileName
The exact AWS profile name to set as the current session profile.

.PARAMETER AccountName
The AWS account name used to locate the profile for the requested role.

.PARAMETER RoleName
The IAM role name used to locate the profile within the AWS account.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.PARAMETER CachePath
The path to the AWS CLI SSO cache directory.

.EXAMPLE
PS> Set-AwsSsoDefaultProfile -ProfileName 'example-nonprod-admin'

Sets `AWS_PROFILE` after confirming the profile's SSO session has a valid cache token.
#>
function Set-AwsSsoDefaultProfile {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ProfileName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ProfileName')]
        [Alias('Profile')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
                    $fakeBoundParameters.ConfigPath
                } else {
                    Join-Path $HOME '.aws\config'
                }

                $cachePath = if ($fakeBoundParameters.ContainsKey('CachePath')) {
                    $fakeBoundParameters.CachePath
                } else {
                    Join-Path $HOME '.aws\sso\cache'
                }

                $activeSessions = @(Get-AwsSsoSessionNames -Active -ConfigPath $configPath -CachePath $cachePath)
                Get-AwsProfileNames -ConfigPath $configPath -ShowSsoSession -ProfileName "$wordToComplete*" |
                    Where-Object { $_.SsoSession -in $activeSessions } |
                    Select-Object -ExpandProperty ProfileName -Unique |
                    Sort-Object
            })]
        [string] $ProfileName,
        [Parameter(ParameterSetName = 'AccountName')]
        [Alias('Account')]
        [ArgumentCompleter({
                [OutputType([System.Management.Automation.CompletionResult])]
                param(
                    [string] $CommandName,
                    [string] $ParameterName,
                    [string] $WordToComplete,
                    [System.Management.Automation.Language.CommandAst] $CommandAst,
                    [System.Collections.IDictionary] $FakeBoundParameters
                )

                $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()

                $script:AccessToken = Get-AWSSSOAccessToken -PassThru

                $script:AccountList = @(Get-SSOAccountList -AccessToken $script:AccessToken |
                        Where-Object { $_.accountName -like "$WordToComplete*" })

                $accountNames = $script:AccountList |
                    Select-Object -ExpandProperty AccountName -Unique |
                    Sort-Object

                foreach ($accountName in $accountNames) {
                    $escapedAccountName = $accountName.Replace("'", "''")
                    $CompletionResults.Add(
                        [System.Management.Automation.CompletionResult]::new(
                            "'$escapedAccountName'",
                            $accountName,
                            [System.Management.Automation.CompletionResultType]::ParameterValue,
                            $accountName
                        )
                    )
                }

                return $CompletionResults
            })]
        [string] $AccountName,
        [parameter(ParameterSetName = 'ProfileName')]
        [parameter(ParameterSetName = 'AccountName')]
        [string] $ConfigPath = (Join-Path $HOME '.aws\config'),
        [parameter(ParameterSetName = 'ProfileName')]
        [parameter(ParameterSetName = 'AccountName')]
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache')
    )

    DynamicParam {
        $RuntimeParamDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()

        if ($PSBoundParameters.ContainsKey('AccountName')) {
            $attr = [System.Management.Automation.ParameterAttribute]::new()
            $attr.Mandatory = $true
            $attr.ParameterSetName = 'AccountName'

            $completerAttr = [System.Management.Automation.ArgumentCompleterAttribute]::new({
                [OutputType([System.Management.Automation.CompletionResult])]
                param(
                    [string] $CommandName,
                    [string] $ParameterName,
                    [string] $WordToComplete,
                    [System.Management.Automation.Language.CommandAst] $CommandAst,
                    [System.Collections.IDictionary] $FakeBoundParameters
                )

                $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()

                $CurrentAccount = $FakeBoundParameters['AccountName']
                $script:AccessToken = Get-AWSSSOAccessToken -PassThru

                $script:AccountList = @(Get-SSOAccountList -AccessToken $script:AccessToken |
                        Where-Object { $_.accountName -eq $CurrentAccount })
                $accountId = $script:AccountList | Where-Object { $_.accountName -eq $CurrentAccount } | Select-Object -ExpandProperty accountId

                $script:Rolelist = Get-SSOAccountRoleList -AccessToken $Script:AccessToken -AccountId $accountId |
                    Where-Object { $_.roleName -like "$WordToComplete*" }

                $script:Rolelist | Select-Object -ExpandProperty RoleName -Unique | Sort-Object | ForEach-Object {
                    $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_))
                }

                return $CompletionResults
            })

            $attrCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
            $attrCollection.Add($attr)
            $attrCollection.Add($completerAttr)

            $param = [System.Management.Automation.RuntimeDefinedParameter]::new('RoleName', [string], $attrCollection)
            $RuntimeParamDictionary.Add('RoleName', $param)
        }

        return $RuntimeParamDictionary
    }

    process {

        # Get Rolename if passed via Dynamic params
        if ($PSBoundParameters.ContainsKey('RoleName')) {
            $RoleName = $PSBoundParameters['RoleName']
        }

        Write-Verbose "profile: '$ProfileName'."

        $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
        Write-Verbose "Parsed AWS config file '$ConfigPath' into $($sections.Count) sections."
        Write-verbose "AccountName: $AccountName"
        Write-verbose "RoleName: $RoleName"

        if ($AccountName -and $RoleName) {
            Write-Verbose "Searching for profile with account '$AccountName' and role '$RoleName'."
            $accountId = Get-SSOAccountList -AccessToken (Get-AWSSSOAccessToken -PassThru) | Where-Object { $_.accountName -eq "$AccountName" } | Select-Object -ExpandProperty accountId
            Write-Verbose "Found account ID '$accountId' for account name '$AccountName'."
            $profileSection = $sections | Where-Object { $_.Type -eq 'profile' -and $_.Properties['sso_account_id'] -eq $accountId -and $_.Properties['sso_role_name'] -eq $RoleName } | Select-Object -First 1
            if ($profileSection) {
                Write-Verbose "Found profile '$($profileSection.Name)' for account '$AccountName' and role '$RoleName'."
                $ProfileName = $profileSection.Name
            }
        } else {
            $profileSection = $sections | Where-Object { $_.Type -eq 'profile' -and $_.Name -eq $ProfileName } | Select-Object -First 1
        }
        if (-not $profileSection) {
            throw "AWS profile '$ProfileName' was not found in '$ConfigPath'."
        }

        $ssoSession = $profileSection.Properties['sso_session']
        if ([string]::IsNullOrWhiteSpace($ssoSession)) {
            throw "AWS profile '$ProfileName' is not associated with an sso-session."
        }

        $activeSessions = @(Get-AwsSsoSessionNames -Active -ConfigPath $ConfigPath -CachePath $CachePath)
        if ($ssoSession -notin $activeSessions) {
            throw "AWS profile '$ProfileName' uses sso-session '$ssoSession', which does not have an active cache token."
        }

        if (-not $PSCmdlet.ShouldProcess('AWS_PROFILE environment variable', "Set to '$ProfileName'")) {
            return
        }

        $env:AWS_PROFILE = $ProfileName
        Write-Verbose "AWS_PROFILE set to '$ProfileName'."
        $env:AWS_PROFILE
    }
}

Set-Alias -Name sadp -Value Set-AwsSsoDefaultProfile

