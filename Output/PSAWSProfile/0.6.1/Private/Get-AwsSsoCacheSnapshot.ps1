function Get-AwsSsoCacheSnapshot {
    [CmdletBinding()]
    param(
        [string] $CachePath = (Join-Path $HOME '.aws\sso\cache')
    )

    if (-not (Test-Path -LiteralPath $CachePath)) {
        Write-Verbose "SSO cache path not found: $CachePath"
        return [pscustomobject]@{
            CachePath = $CachePath
            Files = @()
            Entries = @()
            ValidStartUrls = [System.Collections.Generic.HashSet[string]]::new()
        }
    }

    $resolvedPath = [System.IO.Path]::GetFullPath($CachePath)
    $files = @(Get-ChildItem -LiteralPath $resolvedPath -Filter '*.json' -File -ErrorAction SilentlyContinue)
    $latestWriteTimeUtc = if ($files.Count -gt 0) {
        ($files | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum
    }
    else {
        [datetime]::MinValue
    }

    if ($script:AwsSsoCacheSnapshot -and
        $script:AwsSsoCacheSnapshot.Path -eq $resolvedPath -and
        $script:AwsSsoCacheSnapshot.FileCount -eq $files.Count -and
        $script:AwsSsoCacheSnapshot.LastWriteTimeUtc -eq $latestWriteTimeUtc) {
        Write-Verbose 'Using cached AWS SSO cache snapshot.'
        return $script:AwsSsoCacheSnapshot.Data
    }

    $entries = New-Object 'System.Collections.Generic.List[object]'
    $validStartUrls = [System.Collections.Generic.HashSet[string]]::new()
    $now = [datetimeoffset]::UtcNow

    foreach ($file in $files) {
        try {
            $json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($json.startUrl) -or [string]::IsNullOrWhiteSpace($json.expiresAt)) {
                continue
            }

            $expiresAt = [datetimeoffset]::Parse($json.expiresAt, [System.Globalization.CultureInfo]::InvariantCulture)
            $isValid = $expiresAt -gt $now
            if ($isValid) {
                [void] $validStartUrls.Add($json.startUrl)
            }

            $entries.Add([pscustomobject]@{
                StartUrl = $json.startUrl
                ExpiresAt = $expiresAt
                CacheFile = $file.FullName
                Status = if ($isValid) { 'valid' } else { 'expired' }
                SecondsRemaining = [math]::Floor(($expiresAt - $now).TotalSeconds)
            })
        }
        catch {
        }
    }

    $data = [pscustomobject]@{
        CachePath = $resolvedPath
        Files = $files
        Entries = $entries.ToArray()
        ValidStartUrls = $validStartUrls
    }

    $script:AwsSsoCacheSnapshot = [pscustomobject]@{
        Path = $resolvedPath
        FileCount = $files.Count
        LastWriteTimeUtc = $latestWriteTimeUtc
        Data = $data
    }

    Write-Verbose "Parsed $($entries.Count) AWS SSO cache entr$(if ($entries.Count -eq 1) { 'y' } else { 'ies' }) from disk."
    return $data
}
