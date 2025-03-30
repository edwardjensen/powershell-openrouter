<#
.SYNOPSIS
    A PowerShell module for making requests to the OpenRouter API.
.DESCRIPTION
    This module provides functionality to make requests to the OpenRouter API,
    which allows access to various large language models.

    Features:
    - Basic LLM requests
    - Streaming responses
    - macOS keychain integration for API key storage
    - Default model management

.NOTES
    The OpenRouter API key must be stored in the secure storage appropriate for your platform.
#>

# Get the path to the module's functions directory
$functionPath = Join-Path -Path $PSScriptRoot -ChildPath 'functions'

# Import module variables first
. "$functionPath\ModuleVariables.ps1"

# Import all function files
. "$functionPath\PlatformUtilities.ps1"
. "$functionPath\ApiKeyManagement.ps1"
. "$functionPath\LLMRequests.ps1"
. "$functionPath\ImageRequests.ps1"

# Export module members
Export-ModuleMember -Function @(
    # Platform utilities
    'Get-PlatformType'
    
    # API key management
    'Get-OpenRouterApiKey'
    'Set-OpenRouterApiKey'
    'Set-OpenRouterApiKeyInEnvironment'
    
    # LLM requests
    'New-LLMRequest'
    'Set-DefaultLLM'
    'Get-DefaultLLM'
    
    # Image requests
    'Get-ImageAltText'
)