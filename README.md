# OpenRouterPS

A PowerShell module for interacting with the OpenRouter API, providing access to various AI language models through a simple, consistent interface.

## Features

- Make requests to multiple AI models through a unified API
- Stream responses in real-time as tokens arrive
- Store API keys securely in the macOS keychain
- Set default models for quick access
- Save responses to markdown files
- Customize request parameters (temperature, max tokens, etc.)

## Installation

1. Save the module file as `OpenRouterPS.psm1` in a directory of your choice
2. Import the module:

```powershell
Import-Module ./path/to/OpenRouterPS.psm1
```

For permanent installation, place the module in your PowerShell modules directory.

## API Key Management

Before using the module, you need to store your OpenRouter API key in the macOS keychain:

Using the module's built-in function:

```powershell
Set-OpenRouterApiKey -ApiKey "your-api-key-here"
```

Or using the Terminal directly:

```bash
security add-generic-password -s "OpenRouter" -a "$(whoami)" -w "your-api-key-here"
```

## Core Functions

### New-LLMRequest

The primary function for making requests to AI models through OpenRouter.

#### Basic Usage

```powershell
# Using the default model
New-LLMRequest -Prompt "Tell me a joke"

# Specifying a model
New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke"
```

#### Streaming Responses

```powershell
# Stream the response as tokens arrive
New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke" -Stream

# Stream a longer response
New-LLMRequest -Model "anthropic/claude-3-sonnet" -Prompt "Write a short story about a robot learning to paint" -Stream -MaxTokens 2000

# Stream and also capture the full response
$fullResponse = New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Give me 5 fun facts about space" -Stream -Return
```

#### Customizing Parameters

```powershell
# Adjust temperature and max tokens
New-LLMRequest -Model "openai/gpt-4" -Prompt "Explain quantum physics" -Temperature 0.7 -MaxTokens 1000

# Get the full API response
$response = New-LLMRequest -Model "google/gemini-pro" -Prompt "Write a poem" -ReturnFull
$response | ConvertTo-Json -Depth 10
```

#### Saving to Files

```powershell
# Save response to a markdown file
New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Write a tutorial on PowerShell" -OutFile "tutorial.md"

# Save to file AND display in console
New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Write a tutorial on PowerShell" -OutFile "tutorial.md" -Return
```

### Parameter Reference

| Parameter | Description |
|-----------|-------------|
| `-Model` | The AI model to use (e.g., "anthropic/claude-3-opus") |
| `-Prompt` | The text prompt to send to the AI |
| `-Temperature` | Controls randomness in output (0.0-1.0, default: 0.7) |
| `-MaxTokens` | Maximum number of tokens to generate (default: 1000) |
| `-ReturnFull` | Return the complete API response object |
| `-Stream` | Stream tokens as they arrive in real-time |
| `-Return` | When used with `-Stream`, returns the full response text |
| `-OutFile` | Save response to a markdown file at the specified path |

### Default Model Management

```powershell
# Set the default model
Set-DefaultLLM -Model "anthropic/claude-3-opus"

# Get the current default model
Get-DefaultLLM
```

## Supported Models

OpenRouter supports a variety of AI models including:

- deepseek/deepseek-chat-v3-0324
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

For a complete list of supported models, see the [OpenRouter documentation](https://openrouter.ai/docs).

## Examples

### Interactive Storytelling

```powershell
$prompt = @"
Create a short sci-fi story about a person who discovers they can communicate with technology. 
The story should have a beginning, middle, and end. 
Make it approximately 500 words.
"@

New-LLMRequest -Model "anthropic/claude-3-sonnet" -Prompt $prompt -Stream -MaxTokens 2000
```

### Code Generation

```powershell
$codePrompt = @"
Write a PowerShell function that:
1. Takes a directory path as input
2. Recursively finds all files larger than 100MB
3. Outputs a report with file paths, sizes, and last modified dates
4. Sorts the results by file size (largest first)
"@

New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt $codePrompt -OutFile "large-files-finder.md"
```

### Research Assistant

```powershell
$researchPrompt = @"
I'm researching quantum computing for a presentation. Can you provide:
1. A simple explanation of quantum computing principles
2. Key advantages over classical computing
3. Current limitations and challenges
4. Potential applications in the next 5-10 years
"@

New-LLMRequest -Prompt $researchPrompt -OutFile "quantum-computing-research.md" -Return
```

## Troubleshooting

- If you encounter HTTP 401 errors, your API key may be invalid or expired
- For streaming issues, ensure your PowerShell console supports ANSI escape sequences
- Some models may have usage limits or quotas on the OpenRouter platform

## License

This project is available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
