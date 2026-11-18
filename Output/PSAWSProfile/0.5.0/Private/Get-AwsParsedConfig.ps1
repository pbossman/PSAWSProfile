function Get-AwsParsedConfig {
    [CmdletBinding()]
    param(
        [string] $ConfigPath = (Join-Path $HOME '.aws\config')
    )

    Write-Verbose "Loading parsed AWS config from '$ConfigPath'."

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Verbose "AWS config file not found: $ConfigPath"
        return $null
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($ConfigPath)
    $fileInfo = Get-Item -LiteralPath $resolvedPath
    $lastWriteTimeUtc = $fileInfo.LastWriteTimeUtc

    if ($script:AwsConfigCache -and
        $script:AwsConfigCache.Path -eq $resolvedPath -and
        $script:AwsConfigCache.LastWriteTimeUtc -eq $lastWriteTimeUtc) {
        Write-Verbose 'Using cached parsed AWS config.'
        return $script:AwsConfigCache.Sections
    }

    $sections = New-Object System.Collections.Generic.List[object]
    $currentSection = $null
    $sectionLines = @()

    foreach ($line in Get-Content -LiteralPath $resolvedPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }

        if ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')) {
            if ($null -ne $currentSection) {
                $currentSection.RawText = $sectionLines -join "`n"
                $sections.Add([pscustomobject]$currentSection)
            }

            $headerText = $trimmed.Substring(1, $trimmed.Length - 2).Trim()
            $sectionType = 'other'
            $sectionName = $headerText

            if ($headerText -eq 'default') {
                $sectionType = 'default'
                $sectionName = 'default'
            }
            elseif ($headerText -match '^(?<type>profile|sso-session)\s+(?<name>.+)$') {
                $sectionType = $matches.type
                $sectionName = $matches.name.Trim()
            }

            $currentSection = [ordered]@{
                Header = $trimmed
                FullName = $headerText
                Type = $sectionType
                Name = $sectionName
                Properties = @{}
                RawText = ''
            }
            $sectionLines = @($line)
            continue
        }

        if ($null -ne $currentSection -and $trimmed -match '^(?<key>[^=]+?)\s*=\s*(?<value>.*)$') {
            $currentSection.Properties[$matches.key.Trim()] = $matches.value.Trim()
            $sectionLines += $line
        }
    }

    if ($null -ne $currentSection) {
        $currentSection.RawText = $sectionLines -join "`n"
        $sections.Add([pscustomobject]$currentSection)
    }

    $script:AwsConfigCache = [pscustomobject]@{
        Path = $resolvedPath
        LastWriteTimeUtc = $lastWriteTimeUtc
        Sections = $sections.ToArray()
    }

    Write-Verbose "Parsed $($sections.Count) AWS config section(s) from disk."
    $script:AwsConfigCache.Sections
}
