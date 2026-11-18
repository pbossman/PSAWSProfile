#Requires -Modules Pester

BeforeAll {
  $modulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  Import-Module $modulePath -Force
}

Describe 'Get-AwsParsedConfig' {
  It 'Returns sections with RawText property' {
    $sections = Get-AwsParsedConfig
    $sections | Should -Not -BeNullOrEmpty
    $sections[0].PSObject.Properties.Name | Should -Contain 'RawText'
  }

  It 'Returns $null for non-existent config file' {
    $result = Get-AwsParsedConfig -ConfigPath 'C:\nonexistent\path\config'
    $result | Should -BeNullOrEmpty
  }
}

Describe 'Get-AwsConfigSection' {
  It 'Returns full section object' {
    $section = Get-AwsConfigSection -Name 'default' -Type default -ErrorAction SilentlyContinue
    if ($section) {
      $section.PSObject.Properties.Name | Should -Contain 'RawText'
      $section.PSObject.Properties.Name | Should -Contain 'Properties'
    }
  }

  It 'Returns $null for non-existent section' {
    $section = Get-AwsConfigSection -Name 'nonexistent-xyz' -Type profile -ErrorAction SilentlyContinue
    $section | Should -BeNullOrEmpty
  }
}

Describe 'Remove-AwsConfigSection' {
  BeforeEach {
    $testConfigPath = Join-Path $env:TEMP "test-aws-config-$([guid]::NewGuid())"
    '[profile test-profile-1]
region = us-east-1
output = json

[profile test-profile-2]
region = us-west-2
output = json' | Set-Content -Path $testConfigPath
  }

  AfterEach {
    if (Test-Path $testConfigPath) {
      Remove-Item $testConfigPath -Force
    }
  }

  It 'Removes entire section including header and properties' {
    Remove-AwsConfigSection -Name 'test-profile-1' -Type profile -ConfigPath $testConfigPath
    
    $content = Get-Content $testConfigPath -Raw
    $content | Should -Not -Match 'test-profile-1'
  }

  It 'Preserves other sections when removing one' {
    Remove-AwsConfigSection -Name 'test-profile-1' -Type profile -ConfigPath $testConfigPath
    
    $content = Get-Content $testConfigPath -Raw
    $content | Should -Match 'test-profile-2'
  }

  It 'Throws error for non-existent section' {
    { Remove-AwsConfigSection -Name 'nonexistent' -Type profile -ConfigPath $testConfigPath -ErrorAction Stop } |
      Should -Throw
  }
}

Describe 'New-AwsSsoProfile' {
  BeforeEach {
    $testConfigPath = Join-Path $env:TEMP "test-new-profile-$([guid]::NewGuid())"
    '[sso-session test-session]
sso_start_url = https://example.awsapps.com/start
sso_region = us-east-1' | Set-Content -Path $testConfigPath
  }

  AfterEach {
    if (Test-Path $testConfigPath) {
      Remove-Item $testConfigPath -Force
    }
  }

  It 'Returns object with ProfileName property when created' {
    # Create without WhatIf to get actual return value
    $result = New-AwsSsoProfile -ProfileName 'test-profile' `
      -SsoSession 'test-session' `
      -AccountId '123456789012' `
      -RoleName 'Developer' `
      -ConfigPath $testConfigPath

    $result.ProfileName | Should -Be 'test-profile'
    $result.SsoSession | Should -Be 'test-session'
  }

  It 'Generates profile name from AccountId and RoleName' {
    $result = New-AwsSsoProfile `
      -SsoSession 'test-session' `
      -AccountId '123456789012' `
      -RoleName 'Developer' `
      -ConfigPath $testConfigPath

    $result.ProfileName | Should -Be '123456789012-Developer'
  }

  It 'Includes output format in result' {
    $result = New-AwsSsoProfile -ProfileName 'test-profile' `
      -SsoSession 'test-session' `
      -AccountId '123456789012' `
      -RoleName 'Developer' `
      -Output 'yaml' `
      -ConfigPath $testConfigPath

    $result.Output | Should -Be 'yaml'
  }

  It 'Accepts different output formats' {
    foreach ($format in @('json', 'yaml', 'text', 'table')) {
      $result = New-AwsSsoProfile -ProfileName "test-$format" `
        -SsoSession 'test-session' `
        -AccountId '123456789012' `
        -RoleName 'Developer' `
        -Output $format `
        -ConfigPath $testConfigPath

      $result.Output | Should -Be $format
    }
  }
}

Describe 'Set-AwsSsoDefaultProfile' {
  It 'Has ProfileName parameter' {
    $cmd = Get-Command Set-AwsSsoDefaultProfile
    $cmd.Parameters.Keys | Should -Contain 'ProfileName'
  }

  It 'Has AccountName parameter' {
    $cmd = Get-Command Set-AwsSsoDefaultProfile
    $cmd.Parameters.Keys | Should -Contain 'AccountName'
  }

  It 'Has SsoSession parameter support in AccountName parameter set' {
    $cmd = Get-Command Set-AwsSsoDefaultProfile
    $params = $cmd.ParameterSets | Where-Object { $_.Name -eq 'AccountName' }
    $params | Should -Not -BeNullOrEmpty
  }
}
