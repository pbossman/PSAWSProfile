$script:AwsSsoPromptState = @{
    Profile = $null
    Status = 'unknown'
    CheckedAt = [datetime]::MinValue
}
$script:AwsConfigCache = $null
$script:AwsSsoCacheSnapshot = $null
