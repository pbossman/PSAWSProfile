<#
.SYNOPSIS
Removes an AWS SSO profile from the shared config file.

.DESCRIPTION
Deletes a profile section from the AWS shared config file by name. This removes all configuration for that profile.

.PARAMETER ProfileName
The name of the profile to remove.

.PARAMETER ConfigPath
The path to the AWS shared config file.

.EXAMPLE
PS> Remove-AwsSsoProfile -ProfileName 'prod-admin'

Removes the 'prod-admin' profile from the AWS config file.

.EXAMPLE
PS> Remove-AwsSsoProfile -ProfileName 'dev' -WhatIf

Preview the removal without making changes.
#>
function Remove-AwsSsoProfile {
  [CmdletBinding(SupportsShouldProcess)]
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

      Get-AwsProfileNames -ConfigPath $configPath |
        Where-Object { $_ -like "$wordToComplete*" } |
        Sort-Object
    })]
    [string] $ProfileName,
    [string] $ConfigPath = (Join-Path $HOME '.aws\config')
  )

  Remove-AwsConfigSection -Name $ProfileName -Type profile -ConfigPath $ConfigPath -WhatIf:$WhatIfPreference -Confirm:$ConfirmPreference
}

