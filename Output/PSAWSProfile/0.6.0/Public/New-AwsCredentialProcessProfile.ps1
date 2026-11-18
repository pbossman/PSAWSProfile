<#
.SYNOPSIS
Creates a new AWS credential process profile in the shared config file.

.DESCRIPTION
Adds a new profile section to the AWS shared config file configured to use a credential process. The credential process can be provided as a complete command string or constructed from individual components.

.PARAMETER ProfileName
The name of the new profile to create.

.PARAMETER CredentialProcess
The full command line to execute that returns AWS credentials. Use this when you have the complete command ready.

.PARAMETER ProcessPath
The path to the credential process executable (e.g., C:\aws_roles_anywhere\aws_signing_helper.exe).

.PARAMETER CertificatePath
The path to the certificate file for credential process authentication.

.PARAMETER PrivateKeyPath
The path to the private key file for credential process authentication.

.PARAMETER RoleArn
The ARN of the IAM role for the credential process. Must match format: arn:aws:iam::{account-id}:role/{role-name}

.PARAMETER TrustAnchorArn
The ARN of the trust anchor for AWS Roles Anywhere. Must match format: arn:aws:rolesanywhere:{region}:{account-id}:trust-anchor/{id}

.PARAMETER ProfileArn
The ARN of the profile for AWS Roles Anywhere. Must match format: arn:aws:rolesanywhere:{region}:{account-id}:profile/{id}

.PARAMETER Region
The AWS region for this profile. Defaults to 'us-east-1' if not specified.

.PARAMETER Output
The output format for AWS CLI commands. Defaults to 'json'.

.PARAMETER Force
If specified, replaces an existing profile with the same name. Without this flag, an error is thrown if the profile already exists.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> New-AwsCredentialProcessProfile -ProfileName 'example-automation' -CredentialProcess 'C:\aws_roles_anywhere\aws_signing_helper.exe credential-process --certificate C:\certs\cert.cer --private-key C:\certs\key.key --role-arn arn:aws:iam::123456789012:role/ra-network --trust-anchor-arn arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abc123 --profile-arn arn:aws:rolesanywhere:us-east-1:123456789012:profile/xyz789'

Creates a new credential process profile with a complete command string.

.EXAMPLE
PS> New-AwsCredentialProcessProfile -ProfileName 'example-automation' -ProcessPath 'C:\aws_roles_anywhere\aws_signing_helper.exe' -CertificatePath 'C:\certs\cert.cer' -PrivateKeyPath 'C:\certs\key.key' -RoleArn 'arn:aws:iam::123456789012:role/ra-network' -TrustAnchorArn 'arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abc123' -ProfileArn 'arn:aws:rolesanywhere:us-east-1:123456789012:profile/xyz789'

Creates a credential process profile by specifying individual components.
#>
function New-AwsCredentialProcessProfile {
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'FullCommand')]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
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
    [Parameter(Mandatory, ParameterSetName = 'FullCommand')]
    [ValidateNotNullOrEmpty()]
    [string] $CredentialProcess,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidateScript({ Test-Path $_ })]
    [string] $ProcessPath,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidateScript({ Test-Path $_ })]
    [string] $CertificatePath,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidateScript({ Test-Path $_ })]
    [string] $PrivateKeyPath,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/[\w+=,.@-]+$')]
    [string] $RoleArn,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidatePattern('^arn:aws:rolesanywhere:[a-z0-9-]+:\d{12}:trust-anchor/[\w-]+$')]
    [string] $TrustAnchorArn,
    [Parameter(Mandatory, ParameterSetName = 'Components')]
    [ValidatePattern('^arn:aws:rolesanywhere:[a-z0-9-]+:\d{12}:profile/[\w-]+$')]
    [string] $ProfileArn,
    [string] $Region = 'us-east-1',
    [ValidateSet('json', 'yaml', 'text', 'table')]
    [string] $Output = 'json',
    [switch] $Force,
    [string] $ConfigPath = (Join-Path $HOME '.aws\config')
  )

  Write-Verbose "Creating new credential process profile."

  # Build credential process command if using Components parameter set
  if ($PSCmdlet.ParameterSetName -eq 'Components') {
    $credentialProcess = @(
      "`"$ProcessPath`" credential-process",
      "--certificate `"$CertificatePath`"",
      "--private-key `"$PrivateKeyPath`"",
      "--role-arn $RoleArn",
      "--trust-anchor-arn $TrustAnchorArn",
      "--profile-arn $ProfileArn"
    ) -join ' '
    Write-Verbose "Built credential process command from components."
  }

  $sections = Get-AwsParsedConfig -ConfigPath $ConfigPath
  Write-Verbose "Parsed AWS config file '$ConfigPath' into $($sections.Count) sections."

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

  Write-Verbose "Creating profile '$ProfileName' with credential process."

  if (-not $PSCmdlet.ShouldProcess("AWS config file '$ConfigPath'", "$(if ($existingProfile) { 'Replace' } else { 'Add' }) profile '$ProfileName'")) {
    return
  }

  if ($existingProfile -and $Force) {
    Remove-AwsConfigSection -Name $ProfileName -Type profile -ConfigPath $ConfigPath
  }

  $profileLines = @(
    "[profile $ProfileName]",
    "credential_process = $credentialProcess",
    "region = $Region",
    "output = $Output"
  )

  $profileText = $profileLines -join "`n"

  Add-Content -LiteralPath $ConfigPath -Value "`n$profileText" -Encoding UTF8

  Write-Verbose "Profile '$ProfileName' $(if ($existingProfile) { 'replaced in' } else { 'added to' }) '$ConfigPath'."

  $script:AwsConfigCache = $null

  [pscustomobject]@{
    ProfileName = $ProfileName
    CredentialProcess = $credentialProcess
    Region = $Region
    Output = $Output
  }
}

