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
    The OpenRouter API key must be stored in the macOS keychain with the service name 'OpenRouter'.

# Installation
    
    1. Save this file as `OpenRouterPS.psm1` in a directory of your choice.
    2. Import the module:
    
    ```powershell
    Import-Module ./path/to/OpenRouterPS.psm1
    ```

# Storing your API key in the macOS keychain

    Before using the module, you need to store your OpenRouter API key in the macOS keychain.
    You can do this using the Terminal:
    
    ```bash
    security add-generic-password -s "OpenRouter" -a "$(whoami)" -w "your-api-key-here"
    ```

    Alternatively, use the module's function:
    
    ```powershell
    Set-OpenRouterApiKey -ApiKey "your-api-key-here"
    ```

# Usage

    ## Basic usage:
    ```powershell
    New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke"
    ```

    ## Stream the response to stdout (default behavior):
    ```powershell
    New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke" -Stream
    ```

    ## Stream a longer response and see tokens appear in real-time:
    ```powershell
    New-LLMRequest -Model "anthropic/claude-3-sonnet" -Prompt "Write a short story about a robot learning to paint" -Stream -MaxTokens 2000
    ```

    ## Stream response and also capture the full text (for further processing):
    ```powershell
    $fullResponse = New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Give me 5 fun facts about space" -Stream -Return
    # The response will be streamed to stdout AND stored in $fullResponse
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
    .PARAMETER Stream
        If set, streams the response tokens to stdout as they are received in real-time.
        By default, streaming mode will not return the response to avoid duplicate output.
    .PARAMETER Return
        If set with -Stream, returns the full streamed response in addition to displaying it.
        This is useful when you want to capture the response in a variable for further processing.
        When used with -OutFile, this will also display the output to console.
    .PARAMETER OutFile
        If specified, writes the response to a Markdown file at the given path using a standardized format.
        When this parameter is used, output to console will be suppressed unless -Return is also specified.
    .EXAMPLE
        New-LLMRequest -Prompt "Tell me a joke"
        # Uses the default LLM model
    .EXAMPLE
        New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke" -Stream
        # Uses streaming mode to display tokens as they arrive (without returning the response)
    .EXAMPLE
        New-LLMRequest -Model "anthropic/claude-3-opus" -Prompt "Tell me a joke" -Stream -Return
        # Streams the response AND captures it in a variable
    .EXAMPLE
        New-LLMRequest -Model "openai/gpt-4" -Prompt "Explain quantum physics" -OutFile "physics_explanation.md"
        # Sends the request and saves the response to a Markdown file without displaying in console
    .EXAMPLE
        New-LLMRequest -Model "google/gemini-pro" -Prompt "Write a poem" -OutFile "poem.md" -Return
        # Saves to file AND displays/returns the response
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
        [switch]$ReturnFull = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Stream = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Return = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$OutFile
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
        stream = [bool]$Stream
    } | ConvertTo-Json -Depth 10
    
    # Variable to hold the result that will be returned by the function
    $functionResult = $null

    try {
        $responseContent = $null
        
        if ($Stream) {
            # For streaming, we need to handle the connection differently
            # If OutFile is specified and Return is not set, suppress stdout output
            $suppressOutput = -not [string]::IsNullOrEmpty($OutFile) -and -not $Return
            $streamedResponse = Invoke-StreamingRequest -Uri $baseUrl -Headers $headers -Body $body -ReturnFull:$ReturnFull -SuppressOutput:$suppressOutput
            
            # Capture response for OutFile if needed
            $responseContent = $streamedResponse
            
            # Set the function result if Return is explicitly set
            if ($Return) {
                $functionResult = $streamedResponse
            }
        }
        else {
            # Standard non-streaming request
            $response = Invoke-RestMethod -Uri $baseUrl -Method Post -Headers $headers -Body $body

            if ($response.choices -and $response.choices.Count -gt 0) {
                $responseContent = $response.choices[0].message.content
                
                # Only output to console if not writing to file, or if Return is explicitly set
                if ([string]::IsNullOrEmpty($OutFile) -or $Return) {
                    Write-Host $responseContent -NoNewline
                }
                
                # Set the function result
                if ($ReturnFull) {
                    $functionResult = $response
                } else {
                    $functionResult = $responseContent
                }
            } else {
                # For error cases, only write to error stream if not suppressing output
                if ([string]::IsNullOrEmpty($OutFile) -or $Return) {
                    Write-Error "No content found in the response."
                } else {
                    Write-Verbose "No content found in the response."
                }
                return $null
            }
        }
        
        # Write to Markdown file if OutFile is specified
        if (-not [string]::IsNullOrEmpty($OutFile)) {
            Write-Verbose "Writing response to file: $OutFile"
            
            # Create markdown content in the specified format
            $markdownContent = @"
$responseContent
"@
            
            # Ensure directory exists
            $outFileDirectory = Split-Path -Path $OutFile -Parent
            if ($outFileDirectory -and -not (Test-Path -Path $outFileDirectory)) {
                New-Item -ItemType Directory -Path $outFileDirectory -Force | Out-Null
            }
            
            # Write content to file
            Set-Content -Path $OutFile -Value $markdownContent -Encoding UTF8
            Write-Host "Response saved to $OutFile" -ForegroundColor Green
        }
        
        # IMPORTANT: Only return a value from the function if we're not in streaming mode
        # or if Return is explicitly set
        if ((-not $Stream -or $Return) -and (-not [string]::IsNullOrEmpty($OutFile) -and -not $Return)) {
            # When writing to a file without Return flag, don't return anything to avoid console output
            return
        } elseif (-not $Stream -or $Return) {
            # Otherwise return the function result
            return $functionResult
        }
    }
    catch {
        Write-Error "Error making request to OpenRouter: $_"
        return $null
    }
}

function Invoke-StreamingRequest {
    <#
    .SYNOPSIS
        Makes a streaming request to the OpenRouter API.
    .DESCRIPTION
        Processes a streaming request to the OpenRouter API and outputs tokens as they arrive to stdout.
        This function handles the Server-Sent Events (SSE) format used by OpenRouter's streaming API.
    .PARAMETER Uri
        The URI to send the request to.
    .PARAMETER Headers
        The headers to include in the request.
    .PARAMETER Body
        The body of the request.
    .PARAMETER ReturnFull
        If set, returns the full API response as an object. Otherwise, returns only the text content.
    .PARAMETER SuppressOutput
        If set, collects the output but does not write it to stdout. Useful when saving to a file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        
        [Parameter(Mandatory = $true)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [switch]$ReturnFull = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressOutput = $false
    )

    try {
        # Create the HTTP request
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Method = "POST"
        $request.ContentType = "application/json"
        $request.Accept = "text/event-stream"  # Important for SSE
        $request.ReadWriteTimeout = 300000     # 5 minutes timeout
        $request.Timeout = 300000              # 5 minutes timeout
        
        # Add headers
        foreach ($key in $Headers.Keys) {
            if ($key -ne "Content-Type") {  # Skip Content-Type as it's set above
                $request.Headers.Add($key, $Headers[$key])
            }
        }
        
        # Write body to request stream
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentLength = $bodyBytes.Length
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
        $requestStream.Close()
        
        # Get response
        Write-Verbose "Sending streaming request to OpenRouter API..."
        $response = $request.GetResponse()
        $responseStream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        
        # Prepare to collect full response for ReturnFull option
        $fullResponse = @()
        $fullText = ""
        
        Write-Verbose "Beginning to process streaming response..."
        
        # Process the stream line by line
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            
            # Skip empty lines
            if ([string]::IsNullOrEmpty($line)) {
                continue
            }
            
            # Handle server-sent events format
            if ($line.StartsWith("data:")) {
                # Extract the data portion
                $jsonData = $line.Substring(5).Trim()
                
                # Skip "[DONE]" message which indicates the end of the stream
                if ($jsonData -eq "[DONE]") {
                    Write-Verbose "Received end of stream signal"
                    break
                }
                
                try {
                    # Parse the JSON data
                    $data = $jsonData | ConvertFrom-Json
                    
                    if ($ReturnFull) {
                        $fullResponse += $data
                    }
                    
                    # Extract and display the content
                    if ($data.choices -and $data.choices.Count -gt 0) {
                        # Handle delta format (used by OpenAI-compatible APIs)
                        if ($data.choices[0].PSObject.Properties.Name -contains "delta") {
                            $content = $data.choices[0].delta.content
                        }
                        # Handle standard format (used by some other APIs)
                        elseif ($data.choices[0].PSObject.Properties.Name -contains "message") {
                            $content = $data.choices[0].message.content
                        }
                        
                        if (-not [string]::IsNullOrEmpty($content)) {
                            # Only write to stdout if not suppressed
                            if (-not $SuppressOutput) {
                                [Console]::Write($content)
                            }
                            $fullText += $content
                        }
                    }
                }
                catch {
                    Write-Verbose "Error parsing JSON data: $_"
                    Write-Verbose "Raw data: $jsonData"
                }
            }
        }
        
        # Finish with a newline to ensure proper formatting in the console
        if (-not $SuppressOutput) {
            [Console]::WriteLine()
        }
        
        # Close streams
        $reader.Close()
        $responseStream.Close()
        $response.Close()
        
        Write-Verbose "Streaming complete. Total characters received: $($fullText.Length)"
        
        # Return data based on ReturnFull parameter
        if ($ReturnFull) {
            return $fullResponse
        } else {
            return $fullText
        }
    }
    catch {
        Write-Error "Error in streaming request: $_"
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
$script:DefaultLLMModel = "deepseek/deepseek-chat-v3-0324:free"

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