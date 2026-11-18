function Remove-AwsConfigSection {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,
    [ValidateSet('profile', 'sso-session', 'default')]
    [string] $Type = 'profile',
    [string] $ConfigPath = (Join-Path $HOME '.aws\config')
  )

  Write-Verbose "Removing section '$Type $Name' from '$ConfigPath'."

  if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "AWS config file not found: $ConfigPath"
  }

  $section = Get-AwsConfigSection -Name $Name -Type $Type -ConfigPath $ConfigPath
  if (-not $section) {
    throw "Section '$Type $Name' not found in '$ConfigPath'."
  }

  if (-not $PSCmdlet.ShouldProcess("AWS config file '$ConfigPath'", "Remove section '$Type $Name'")) {
    return
  }

  $configContent = Get-Content -LiteralPath $ConfigPath -Raw

  $headerPattern = "(?ms)^\s*\[$Type $([regex]::Escape($Name))\].*?(?=\n\n|\n\[|\Z)"
  Write-Verbose "Pattern: $headerPattern"

  # Debug: Show what will be removed
  $matchCollection = [regex]::Matches($configContent, $headerPattern)
  if ($matchCollection.Count -gt 0) {
    Write-Verbose "Pattern matched! Found $($matchCollection.Count) match(es)"
    foreach ($match in $matchCollection) {
      $lines = @($match.Value -split "`n")
      Write-Verbose "Match contains $($lines.Count) lines (Value length: $($match.Value.Length) chars)"
    }
  } else {
    Write-Warning "Pattern did NOT match!"
  }

  Write-Verbose "Before removal, file size: $($configContent.Length) bytes"
  $configContent = $configContent -replace $headerPattern, ''
  Write-Verbose "After removal, file size: $($configContent.Length) bytes"

  Set-Content -LiteralPath $ConfigPath -Value $configContent -Encoding UTF8 -Confirm:$false

  Write-Verbose "Section '$Type $Name' removed from '$ConfigPath'."

  $script:AwsConfigCache = $null
}
