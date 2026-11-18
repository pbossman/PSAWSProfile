# PSAWSProfile

Comprehensive AWS profile management for PowerShell with support for SSO, assumed roles, and credential process profiles.

## Features

- **SSO Profile Management** — Create and manage AWS SSO profiles with auto-generated names
- **Assumed Role Profiles** — Configure cross-account role assumption with built-in ARN validation
- **Credential Process** — Support for AWS Roles Anywhere and custom credential providers
- **Dynamic Parameters** — Smart parameter dependency (RoleName only appears when AccountName is set)
- **Full Config Inspection** — Read complete AWS config sections with raw multiline content
- **Argument Completers** — Tab completion for profiles, accounts, roles, and sessions

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name PSAWSProfile -Scope CurrentUser
```

### From GitHub

```powershell
git clone https://github.com/pbossman/PSAWSProfile.git
Import-Module ./PSAWSProfile/PSAWSProfile.psd1
```

## Quick Start

### List AWS SSO Sessions

```powershell
# All configured sessions
Get-AwsSsoSessionNames

# Only active sessions (with valid cached tokens)
Get-AwsSsoSessionNames -Active
```

### List Profiles

```powershell
# All profiles
Get-AwsProfileNames

# Profiles for specific SSO session
Get-AwsProfileNames -SsoSession example-sso
```

### Create SSO Profile

```powershell
# With auto-generated name (AccountId-RoleName)
New-AwsSsoProfile -SsoSession example-sso `
  -AccountName Production `
  -RoleName Developer

# With explicit name
New-AwsSsoProfile -ProfileName prod-dev `
  -SsoSession example-sso `
  -AccountId 123456789012 `
  -RoleName Developer
```

### Create Assumed Role Profile

```powershell
New-AwsAssumedRoleProfile -ProfileName cross-account-role `
  -SourceProfile base-profile `
  -RoleArn 'arn:aws:iam::123456789012:role/example-role'
```

### Create Credential Process Profile

**Complete command:**
```powershell
New-AwsCredentialProcessProfile -ProfileName aws-roles-anywhere `
  -CredentialProcess 'C:\aws_signing_helper.exe credential-process --certificate C:\certs\cert.cer --private-key C:\certs\key.key --role-arn arn:aws:iam::123456789012:role/example --trust-anchor-arn arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abc123 --profile-arn arn:aws:rolesanywhere:us-east-1:123456789012:profile/xyz789'
```

**With components:**
```powershell
New-AwsCredentialProcessProfile -ProfileName aws-roles-anywhere `
  -ProcessPath 'C:\aws_signing_helper.exe' `
  -CertificatePath 'C:\certs\cert.cer' `
  -PrivateKeyPath 'C:\certs\key.key' `
  -RoleArn 'arn:aws:iam::123456789012:role/example' `
  -TrustAnchorArn 'arn:aws:rolesanywhere:us-east-1:123456789012:trust-anchor/abc123' `
  -ProfileArn 'arn:aws:rolesanywhere:us-east-1:123456789012:profile/xyz789'
```

### Set Active Profile

```powershell
# Using profile name
Set-AwsSsoDefaultProfile -ProfileName prod-dev

# Using account and role (with dynamic RoleName parameter)
Set-AwsSsoDefaultProfile -AccountName Production -RoleName Developer

# Alias available
sadp prod-dev
```

### Remove Profile

```powershell
Remove-AwsSsoProfile -ProfileName prod-dev
```

## Cmdlets

| Cmdlet | Purpose |
|--------|---------|
| `New-AwsSsoProfile` | Create SSO profiles |
| `New-AwsAssumedRoleProfile` | Create assumed role profiles |
| `New-AwsCredentialProcessProfile` | Create credential process profiles |
| `Remove-AwsSsoProfile` | Remove profiles |
| `Get-AwsProfileNames` | List profiles |
| `Get-AwsSsoSessionNames` | List SSO sessions |
| `Get-AwsConfigSection` | Read profile configuration |
| `Set-AwsSsoDefaultProfile` | Set active profile |

## Configuration

All cmdlets support optional parameters:

- `-Region` — AWS region (default: us-east-1)
- `-Output` — Output format: json, yaml, text, table (default: json)
- `-Force` — Replace existing profiles
- `-ConfigPath` — Custom AWS config path (default: ~/.aws/config)

## Testing

Run the test suite:

```powershell
Invoke-Pester PSAWSProfile/Tests/PSAWSProfile.Tests.ps1
```

## Requirements

- PowerShell 7+
- Windows, macOS, or Linux
- AWS CLI shared config file (~/.aws/config)

## License

MIT

## Contributing

Contributions welcome! Please ensure tests pass before submitting PRs.

## Support

For issues and feature requests: https://github.com/pbossman/PSAWSProfile/issues
