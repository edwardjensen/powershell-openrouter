<#
.SYNOPSIS
    A PowerShell module for making requests to the OpenRouter API.
.DESCRIPTION
    This module provides functionality to make requests to the OpenRouter API,
    which allows access to various large language models.

.NOTES
    The OpenRouter API key must be stored in the macOS keychain with the service name 'OpenRouter'.

# Installation
    
    1. Save this file as `OpenRouter.psm1` in a directory of your choice.
    2. Import the module:
    
    ```powershell
    Import-Module ./path/to/OpenRouter.psm1
    ```

# Storing your API key in the macOS keychain

    Before using the module, you need to store your OpenRouter API key in the macOS keychain.
    You can do this using the Terminal:
    
    ```bash
    security add-generic-password -s "OpenRouter" -a "$(whoami)" -w "your-api-key-here"
    ```

# Usage

    ## Basic usage:
    ```powershell
    New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke"
    ```

    ## With additional parameters:
    ```powershell
    New-LLMRequest -Model "openai/gpt-4" -Prompt "Explain quantum physics" -Temperature 0.7 -MaxTokens 1000
    ```

    ## Get the full API response:
    ```powershell
    $response = New-LLMRequest -Model "google/gemini-pro" -Prompt "Write a poem" -ReturnFull
    $response | ConvertTo-Json -Depth 10
    ```

# Available models

    OpenRouter supports a variety of models. Here are some examples:
    
    - anthropic/claude-3-opus
    - anthropic/claude-3-sonnet
    - anthropic/claude-3-haiku
    - openai/gpt-4
    - openai/gpt-4-turbo
    - openai/gpt-3.5-turbo
    - google/gemini-pro
    - google/gemini-1.5-pro
    - mistral/mistral-medium
    - mistral/mistral-large
    
    For a full list of supported models, refer to the OpenRouter documentation (https://openrouter.ai/docs).
#>

function New-LLMRequest {
    <#
    .SYNOPSIS
        Makes a request to the OpenRouter API.
    .DESCRIPTION
        Makes a request to the OpenRouter API using the specified model and prompt.
        If no model is specified, uses the default model set by Set-DefaultLLM.
        Returns the response from the API.
    .PARAMETER Model
        The name of the LLM model to use. If not provided, the default model will be used.
    .PARAMETER Prompt
        The prompt to send to the model.
    .PARAMETER Temperature
        Controls randomness: Lowering results in less random completions. 
        As the temperature approaches zero, the model will become deterministic and repetitive.
    .PARAMETER MaxTokens
        The maximum number of tokens to generate in the completion.
    .PARAMETER ReturnFull
        If set, returns the full API response as an object. Otherwise, returns only the text content.
    .EXAMPLE
        New-LLMRequest -Prompt "Tell me a joke"
        # Uses the default LLM model
    .EXAMPLE
        New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke"
        # Explicitly specifies the model
    .EXAMPLE
        New-LLMRequest -Model "openai/gpt-4" -Prompt "Explain quantum physics" -Temperature 0.7 -MaxTokens 1000
    .EXAMPLE
        New-LLMRequest -Model "google/gemini-pro" -Prompt "Write a poem" -ReturnFull
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Model,
        
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        
        [Parameter(Mandatory = $false)]
        [double]$Temperature = 0.7,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxTokens = 1000,
        
        [Parameter(Mandatory = $false)]
        [switch]$ReturnFull = $false
    )
    
    # Use default model if none specified
    if ([string]::IsNullOrEmpty($Model)) {
        $Model = $script:DefaultLLMModel
        Write-Verbose "No model specified. Using default model: $Model"
    }

    # Get the API key from the macOS keychain
    $apiKey = Get-OpenRouterApiKey

    # Base URL for the OpenRouter API
    $baseUrl = "https://openrouter.ai/api/v1/chat/completions"

    # Prepare headers
    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
        "HTTP-Referer" = "https://localhost" # Required by OpenRouter
        "X-Title" = "PowerShell OpenRouter Module" # Optional but recommended
    }

    # Prepare the request body
    $body = @{
        model = $Model
        messages = @(
            @{
                role = "user"
                content = $Prompt
            }
        )
        temperature = $Temperature
        max_tokens = $MaxTokens
    } | ConvertTo-Json -Depth 10

    try {
        # Make the API call
        $response = Invoke-RestMethod -Uri $baseUrl -Method Post -Headers $headers -Body $body

        # Return the response based on the ReturnFull parameter
        if ($ReturnFull) {
            return $response
        } else {
            if ($response.choices -and $response.choices.Count -gt 0) {
                return $response.choices[0].message.content
            } else {
                Write-Error "No content found in the response."
                return $null
            }
        }
    }
    catch {
        Write-Error "Error making request to OpenRouter: $_"
        return $null
    }
}

function Get-OpenRouterApiKey {
    <#
    .SYNOPSIS
        Retrieves the OpenRouter API key from the macOS keychain.
    .DESCRIPTION
        Uses the security command on macOS to retrieve the OpenRouter API key
        from the keychain.
    #>
    [CmdletBinding()]
    param()

    try {
        # Use the security command to access the macOS keychain
        $apiKey = security find-generic-password -s "OpenRouter" -w 2>$null
        
        if ([string]::IsNullOrEmpty($apiKey)) {
            throw "API key not found in keychain. Please ensure it is stored with service name 'OpenRouter'."
        }
        
        return $apiKey
    }
    catch {
        Write-Error "Failed to retrieve API key from macOS keychain: $_"
        throw
    }
}

# Module variable to store the default LLM model
$script:DefaultLLMModel = "anthropic/claude-3-haiku"

function Set-OpenRouterApiKey {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in the macOS keychain.
    .DESCRIPTION
        Uses the security command on macOS to store the OpenRouter API key
        in the keychain, creating a new entry or updating an existing one.
    .PARAMETER ApiKey
        The OpenRouter API key to store.
    .EXAMPLE
        Set-OpenRouterApiKey -ApiKey "your-api-key-here"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    try {
        # Get the current username
        $username = $(whoami)
        
        # First, try to delete any existing entry
        $null = security delete-generic-password -s "OpenRouter" 2>$null
        
        # Add the new password entry
        $result = security add-generic-password -s "OpenRouter" -a "$username" -w "$ApiKey" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "OpenRouter API key has been successfully stored in the macOS keychain." -ForegroundColor Green
        } else {
            throw "Failed to store API key: $result"
        }
    }
    catch {
        Write-Error "Failed to store API key in macOS keychain: $_"
        throw
    }
}

function Set-DefaultLLM {
    <#
    .SYNOPSIS
        Sets the default LLM model for OpenRouter requests.
    .DESCRIPTION
        Sets a default LLM model to use when no model is specified in New-LLMRequest.
    .PARAMETER Model
        The name of the LLM model to set as default.
    .EXAMPLE
        Set-DefaultLLM -Model "anthropic/claude-3-opus"
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Model
    )

    $script:DefaultLLMModel = $Model
    Write-Host "Default LLM model set to: $Model" -ForegroundColor Green
}

function Get-DefaultLLM {
    <#
    .SYNOPSIS
        Gets the current default LLM model.
    .DESCRIPTION
        Returns the currently configured default LLM model for OpenRouter requests.
    .EXAMPLE
        Get-DefaultLLM
    #>
    [CmdletBinding()]
    param()

    return $script:DefaultLLMModel
}

# Export the public functions
Export-ModuleMember -Function New-LLMRequest, Set-OpenRouterApiKey, Set-DefaultLLM, Get-DefaultLLM