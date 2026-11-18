$moduleRoot = Join-Path $PSScriptRoot '..\PSAWSProfile'

$devModule = New-Module -Name PSAWSProfileDev -ArgumentList $moduleRoot -ScriptBlock {
    param($ModuleRoot)

    $public = Get-ChildItem (Join-Path $ModuleRoot 'Public\*.ps1') -ErrorAction Stop
    $private = Get-ChildItem (Join-Path $ModuleRoot 'Private\*.ps1') -ErrorAction Stop

    foreach ($script in @($public) + @($private)) {
        . $script.FullName
    }

    Export-ModuleMember -Function * -Alias *
}

Import-Module $devModule -Force -Verbose
