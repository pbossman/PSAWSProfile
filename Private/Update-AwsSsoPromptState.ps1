<#
.SYNOPSIS
Refreshes cached prompt state for the current AWS SSO profile.

.DESCRIPTION
Updates the module's cached prompt state for the current `AWS_PROFILE` and stores the resulting status in `AWS_SSO_STATUS`.

.PARAMETER Force
Forces a refresh even if the cached prompt state is still considered fresh.

.EXAMPLE
PS> Update-AwsSsoPromptState -Force

Refreshes the current prompt state and updates the `AWS_SSO_STATUS` environment variable.
#>
function Update-AwsSsoPromptState {
    [CmdletBinding(SupportsShouldProcess)]
    param([switch] $Force)

    $currentProfile = $env:AWS_PROFILE
    if ([string]::IsNullOrWhiteSpace($currentProfile)) {
        if (-not $PSCmdlet.ShouldProcess('AWS_SSO_STATUS environment variable and cached prompt state', 'Clear for missing AWS profile')) {
            return
        }

        $script:AwsSsoPromptState = @{
            Profile = $null
            Status = 'no-profile'
            CheckedAt = Get-Date
        }
        $env:AWS_SSO_STATUS = 'no-profile'
        return
    }

    $cacheAgeSeconds = ((Get-Date) - $script:AwsSsoPromptState.CheckedAt).TotalSeconds
    $shouldRefresh = $Force -or
        $script:AwsSsoPromptState.Profile -ne $currentProfile -or
        $cacheAgeSeconds -ge 300

    if ($shouldRefresh) {
        if (-not $PSCmdlet.ShouldProcess('AWS_SSO_STATUS environment variable and cached prompt state', "Refresh for profile '$currentProfile'")) {
            return
        }

        $result = Test-AwsSsoProfile -ProfileName $currentProfile -PassThru
        $script:AwsSsoPromptState = @{
            Profile = $result.Profile
            Status = $result.Status
            CheckedAt = $result.CheckedAt
        }

        $env:AWS_SSO_STATUS = $script:AwsSsoPromptState.Status
        return
    }

    if ($env:AWS_SSO_STATUS -ne $script:AwsSsoPromptState.Status) {
        if (-not $PSCmdlet.ShouldProcess('AWS_SSO_STATUS environment variable', "Set to '$($script:AwsSsoPromptState.Status)'")) {
            return
        }

        $env:AWS_SSO_STATUS = $script:AwsSsoPromptState.Status
    }
}
