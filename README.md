# OpenRouterPS

A PowerShell module for making requests to the OpenRouter API, providing access to various large language models (LLMs) including Claude, GPT-4, Gemini, and more.

## Overview

OpenRouterPS simplifies interaction with the OpenRouter API, allowing you to easily send prompts to various AI models and receive responses directly in your PowerShell environment.

## Installation

1. Download the `OpenRouterPS.psm1` file to your preferred location
2. Import the module:

```powershell
Import-Module ./path/to/OpenRouterPS.psm1
```

For permanent installation, copy the module to your PowerShell modules directory:

```powershell
# Create directory if it doesn't exist
$modulesPath = "$HOME/Documents/PowerShell/Modules/OpenRouterPS"
New-Item -ItemType Directory -Path $modulesPath -Force

# Copy the module file
Copy-Item ./OpenRouterPS.psm1 $modulesPath/

# Import the module
Import-Module OpenRouterPS
```

## Configuration

### API Key

Before using the module, you need to store your OpenRouter API key in the macOS keychain:

**Option 1:** Use the module's built-in function:

```powershell
Set-OpenRouterApiKey -ApiKey "your-api-key-here"
```

**Option 2:** Use the Terminal directly:

```bash
security add-generic-password -s "OpenRouter" -a "$(whoami)" -w "your-api-key-here"
```

### Default Model

Set a default model to use when no specific model is requested:

```powershell
Set-DefaultLLM -Model "anthropic/claude-3-opus"
```

Check the current default model:

```powershell
Get-DefaultLLM
```

## Usage

### Basic Request

```powershell
# Use the default model
New-LLMRequest -Prompt "Tell me a joke"

# Specify a model
New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke"
```

### Advanced Options

```powershell
# Set temperature and max tokens
New-LLMRequest -Model "openai/gpt-4" -Prompt "Explain quantum physics" -Temperature 0.7 -MaxTokens 1000

# Get the full API response
$response = New-LLMRequest -Model "google/gemini-pro" -Prompt "Write a poem" -ReturnFull
$response | ConvertTo-Json -Depth 10
```

## Available Models

OpenRouterPS supports all models available through OpenRouter. Here are some popular options:

- `anthropic/claude-3-opus`
- `anthropic/claude-3-sonnet`
- `anthropic/claude-3-haiku`
- `openai/gpt-4`
- `openai/gpt-4-turbo`
- `openai/gpt-3.5-turbo`
- `google/gemini-pro`
- `google/gemini-1.5-pro`
- `mistral/mistral-medium`
- `mistral/mistral-large`

For a complete list, visit the [OpenRouter documentation](https://openrouter.ai/docs).

## Requirements

- PowerShell 7.0 or higher (recommended)
- macOS (the module uses macOS keychain for secure API key storage)
- An OpenRouter account and API key

## Functions Reference

| Function | Description |
|----------|-------------|
| `New-LLMRequest` | Makes a request to the OpenRouter API |
| `Set-OpenRouterApiKey` | Stores your API key in the macOS keychain |
| `Get-OpenRouterApiKey` | Retrieves your API key from the keychain |
| `Set-DefaultLLM` | Sets the default LLM model |
| `Get-DefaultLLM` | Returns the currently set default model |

## License

MIT

## Acknowledgements

This module is not officially affiliated with OpenRouter. It is a community-created tool for easier access to the OpenRouter API from PowerShell on macOS.
