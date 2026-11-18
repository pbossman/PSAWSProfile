<#
.SYNOPSIS
Creates a new AWS SSO profile in the shared config file.

.DESCRIPTION
Adds a new profile section to the AWS shared config file configured to use AWS SSO for authentication. The profile references an existing SSO session and specifies the target AWS account and IAM role. If no profile name is specified, defaults to '{AccountId}-{RoleName}'.

.PARAMETER ProfileName
The name of the new profile to create. If not specified, defaults to '{AccountId}-{RoleName}'.

.PARAMETER SsoSession
The name of the SSO session to use for this profile. Must reference an existing sso-session section in the config file.

.PARAMETER AccountName
The friendly name of the AWS account. Used to locate the account ID via AWS SSO.

.PARAMETER AccountId
The AWS account ID directly. Used as an alternative to AccountName.

.PARAMETER RoleName
The IAM role name within the specified account to associate with this profile.

.PARAMETER Region
The AWS region for this profile. Defaults to 'us-east-1' if not specified.

.PARAMETER Output
The output format for AWS CLI commands. Defaults to 'json'.

.PARAMETER Force
If specified, replaces an existing profile with the same name. Without this flag, an error is thrown if the profile already exists.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> New-AwsSsoProfile -SsoSession 'my-sso' -AccountName 'Production' -RoleName 'Administrator' -Region 'us-west-2'

Creates a new profile with auto-generated name from the account ID and role name.

.EXAMPLE
PS> New-AwsSsoProfile -ProfileName 'prod-admin' -SsoSession 'my-sso' -AccountName 'Production' -RoleName 'Administrator'

Creates a new profile named 'prod-admin' configured to use the 'my-sso' session for the Production account's Administrator role.

.EXAMPLE
PS> New-AwsSsoProfile -ProfileName 'dev' -SsoSession 'my-sso' -AccountId '123456789012' -RoleName 'Developer' -Force

Creates or replaces a profile using the account ID directly.
#>
function New-AwsSsoProfile {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

      $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
        $fakeBoundParameters.ConfigPath
      } else {
        Join-Path $HOME '.aws\config'
      }

      $existingProfiles = Get-AwsProfileNames -ConfigPath $configPath |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object

      return $existingProfiles
    })]
    [string] $ProfileName,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

      $configPath = if ($fakeBoundParameters.ContainsKey('ConfigPath')) {
        $fakeBoundParameters.ConfigPath
      } else {
        Join-Path $HOME '.aws\config'
      }

      Get-AwsSsoSessionNames -ConfigPath $configPath |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object
    })]
    [Alias('sso-session')]
    [string] $SsoSession,
    [Parameter(ParameterSetName = 'ByAccountName')]
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
    [Parameter(ParameterSetName = 'ByAccountId')]
    [ValidatePattern('^\d{12}$')]
    [string] $AccountId,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
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

      $CurrentAccount = $null
      if ($FakeBoundParameters.ContainsKey('AccountName')) {
        $CurrentAccount = $FakeBoundParameters['AccountName']
        $script:AccountList = @(Get-SSOAccountList -AccessToken $script:AccessToken |
          Where-Object { $_.accountName -eq $CurrentAccount })
      } elseif ($FakeBoundParameters.ContainsKey('AccountId')) {
        $CurrentAccount = $FakeBoundParameters['AccountId']
        $script:AccountList = @(Get-SSOAccountList -AccessToken $script:AccessToken |
          Where-Object { $_.accountId -eq $CurrentAccount })
      }

      if ($null -ne $CurrentAccount) {
        $accountId = $script:AccountList | Select-Object -ExpandProperty accountId -First 1

        $script:Rolelist = Get-SSOAccountRoleList -AccessToken $Script:AccessToken -AccountId $accountId |
          Where-Object { $_.roleName -like "$WordToComplete*" }

        $script:Rolelist | Select-Object -ExpandProperty RoleName -Unique | Sort-Object | ForEach-Object {
          $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_))
        }
      }

      return $CompletionResults
    })]
    [string] $RoleName,
    [string] $Region = 'us-east-1',
    [ValidateSet('json', 'yaml', 'text', 'table')]
    [string] $Output = 'json',
    [switch] $Force,
    [string] $ConfigPath = (Join-Path $HOME '.aws\config')
  )

  Write-Verbose "Creating new SSO profile."

  $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
  Write-Verbose "Parsed AWS config file '$ConfigPath' into $($sections.Count) sections."

  if ($PSBoundParameters.ContainsKey('AccountName')) {
    Write-Verbose "Looking up account ID for account name '$AccountName'."
    $token = Get-AWSSSOAccessToken -PassThru
    $accountId = Get-SSOAccountList -AccessToken $token |
      Where-Object { $_.accountName -eq $AccountName } |
      Select-Object -ExpandProperty accountId |
      Select-Object -First 1

    if (-not $accountId) {
      throw "Account name '$AccountName' not found in SSO."
    }
  } else {
    $accountId = $AccountId
  }

  if (-not $ProfileName) {
    $ProfileName = "$accountId-$RoleName"
    Write-Verbose "Profile name not specified; generated name: '$ProfileName'."
  }

  $existingProfile = $sections | Where-Object { $_.Type -eq 'profile' -and $_.Name -eq $ProfileName } | Select-Object -First 1
  if ($existingProfile -and -not $Force) {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
      [System.Exception]::new("Profile '$ProfileName' already exists. Re-run with -Force to update it."),
      'ProfileAlreadyExists',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $ProfileName
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
  }

  Write-Verbose "Creating profile '$ProfileName' with account ID '$accountId' and role '$RoleName'."

  if (-not $PSCmdlet.ShouldProcess("AWS config file '$ConfigPath'", "$(if ($existingProfile) { 'Replace' } else { 'Add' }) profile '$ProfileName'")) {
    return
  }

  if ($existingProfile -and $Force) {
    Remove-AwsConfigSection -Name $ProfileName -Type profile -ConfigPath $ConfigPath
  }

  $profileLines = @(
    "[profile $ProfileName]",
    "sso_session = $SsoSession",
    "sso_account_id = $accountId",
    "sso_role_name = $RoleName",
    "region = $Region",
    "output = $Output"
  )

  $profileText = $profileLines -join "`n"

  Add-Content -LiteralPath $ConfigPath -Value "`n$profileText" -Encoding UTF8

  Write-Verbose "Profile '$ProfileName' $(if ($existingProfile) { 'replaced in' } else { 'added to' }) '$ConfigPath'."

  $script:AwsConfigCache = $null

  [pscustomobject]@{
    ProfileName = $ProfileName
    SsoSession = $SsoSession
    AccountId = $accountId
    RoleName = $RoleName
    Region = $Region
    Output = $Output
  }
}







