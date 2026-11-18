# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [0.6.1] - 2026-11-18

### Added
- Comprehensive README with examples and feature overview
- Quick start guide for all profile types
- Cmdlet reference table

## [Unreleased]

## [0.6.0] - 2026-11-17

### Added

- **New-AwsSsoProfile**: Create new AWS SSO profiles with optional auto-generated names (defaults to {AccountId}-{RoleName}). Supports parameter sets for account name or account ID selection with argument completers.
- **New-AwsAssumedRoleProfile**: Create assumed role profiles with source profile and role ARN. Validates role ARN against AWS format regex. Auto-generates profile names from ARN components.
- **New-AwsCredentialProcessProfile**: Create credential process profiles for AWS Roles Anywhere and custom credential providers. Supports two parameter sets: complete command string or component-based construction with parameter validation.
- **Remove-AwsConfigSection**: Generic function to remove any AWS config section by name and type. Properly removes header and all properties while preserving blank line separators.
- **Dynamic RoleName parameter**: Set-AwsSsoDefaultProfile now implements RoleName as a dynamic parameter that only appears when AccountName is specified.
- **RawText property**: Get-AwsParsedConfig now includes a RawText property containing the raw multiline text of each section.
- **Full section objects**: Get-AwsConfigSection now returns the complete section object including Header, Type, Name, Properties, and RawText.
- **Comprehensive Pester tests**: Added test suite covering all new cmdlets, parameter validation, error handling, and profile management workflows.

### Changed

- Improved section removal with multiline-aware regex pattern using dotall mode.
- Enhanced error messages in profile creation cmdlets using ThrowTerminatingError for cleaner error display.

### Fixed

- Section removal pattern now properly matches entire sections including header and all properties.
- ARN validation regex patterns for assumed role and credential process profiles.

