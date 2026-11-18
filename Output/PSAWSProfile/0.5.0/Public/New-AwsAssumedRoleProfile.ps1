<#
.SYNOPSIS
Creates a new AWS assumed role profile in the shared config file.

.DESCRIPTION
Adds a new profile section to the AWS shared config file configured to assume an IAM role. The profile references a source profile and specifies the role ARN to assume.

.PARAMETER ProfileName
The name of the new profile to create. If not specified, defaults to '{AccountId}-{RoleName}' extracted from the role ARN.

.PARAMETER SourceProfile
The name of the profile to use as the source for assuming the role.

.PARAMETER RoleArn
The ARN of the IAM role to assume. Must match AWS ARN format: arn:aws:iam::{account-id}:role/{role-name}

.PARAMETER Region
The AWS region for this profile. Defaults to 'us-east-1' if not specified.

.PARAMETER Output
The output format for AWS CLI commands. Defaults to 'json'.

.PARAMETER Force
If specified, replaces an existing profile with the same name. Without this flag, an error is thrown if the profile already exists.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> New-AwsAssumedRoleProfile -ProfileName 'prod-role' -SourceProfile 'prod-automation' -RoleArn 'arn:aws:iam::123456789012:role/example-role'

Creates a new assumed role profile named 'prod-role'.

.EXAMPLE
PS> New-AwsAssumedRoleProfile -SourceProfile 'prod-automation' -RoleArn 'arn:aws:iam::123456789012:role/example-role'

Creates a new assumed role profile with auto-generated name from the ARN.
#>
function New-AwsAssumedRoleProfile {
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

      Get-AwsProfileNames -ConfigPath $configPath |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object
    })]
    [string] $SourceProfile,
    [Parameter(Mandatory)]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/[\w+=,.@-]+$')]
    [string] $RoleArn,
    [string] $Region = 'us-east-1',
    [ValidateSet('json', 'yaml', 'text', 'table')]
    [string] $Output = 'json',
    [switch] $Force,
    [string] $ConfigPath = (Join-Path $HOME '.aws\config')
  )

  Write-Verbose "Creating new assumed role profile."

  $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
  Write-Verbose "Parsed AWS config file '$ConfigPath' into $($sections.Count) sections."

  if (-not $ProfileName) {
    # Extract account ID and role name from ARN
    # ARN format: arn:aws:iam::{account-id}:role/{role-name}
    if ($RoleArn -match 'arn:aws:iam::(\d{12}):role/([\w+=,.@-]+)$') {
      $accountId = $matches[1]
      $roleName = $matches[2]
      $ProfileName = "$accountId-$roleName"
      Write-Verbose "Profile name not specified; generated name: '$ProfileName'."
    }
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

  Write-Verbose "Creating profile '$ProfileName' for role ARN '$RoleArn'."

  if (-not $PSCmdlet.ShouldProcess("AWS config file '$ConfigPath'", "$(if ($existingProfile) { 'Replace' } else { 'Add' }) profile '$ProfileName'")) {
    return
  }

  if ($existingProfile -and $Force) {
    Remove-AwsConfigSection -Name $ProfileName -Type profile -ConfigPath $ConfigPath
  }

  $profileLines = @(
    "[profile $ProfileName]",
    "source_profile = $SourceProfile",
    "role_arn = $RoleArn",
    "region = $Region",
    "output = $Output"
  )

  $profileText = $profileLines -join "`n"

  Add-Content -LiteralPath $ConfigPath -Value "`n$profileText" -Encoding UTF8

  Write-Verbose "Profile '$ProfileName' $(if ($existingProfile) { 'replaced in' } else { 'added to' }) '$ConfigPath'."

  $script:AwsConfigCache = $null

  [pscustomobject]@{
    ProfileName = $ProfileName
    SourceProfile = $SourceProfile
    RoleArn = $RoleArn
    Region = $Region
    Output = $Output
  }
}

