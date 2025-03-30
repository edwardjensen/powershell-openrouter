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

# Storing your OpenRouter API key

    Set your API key using the module's function:
    
    ```powershell
    Set-OpenRouterApiKey -ApiKey "your-api-key-here"
    ```
    
    This will store your API key in the appropriate secure storage for your platform:
    - macOS: macOS keychain
    - Windows: Windows Credential Manager
    - Linux: Secret Service API (via secret-tool) or password-store.org
    
    If no secure storage is available, or if you prefer to use environment variables:
    
    ```powershell
    Set-OpenRouterApiKey -ApiKey "your-api-key-here" -UseEnvironmentVariableOnly -Scope "User"
    ```
    
    Valid scopes are "Process" (default), "User", and "Machine".

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

# Add these functions to your OpenRouterPS.psm1 module

function Get-PlatformType {
    <#
    .SYNOPSIS
        Detects the current operating system platform.
    .DESCRIPTION
        Returns a string indicating the current platform: "Windows", "Linux", or "MacOS".
        This helps determine which secret management approach to use.
    .EXAMPLE
        $platform = Get-PlatformType
        # Returns "MacOS" when run on macOS
    #>
    [CmdletBinding()]
    param()
    
    if ($IsWindows -or ($PSVersionTable.PSVersion.Major -lt 6 -and -not $IsLinux -and -not $IsMacOS)) {
        return "Windows"
    }
    elseif ($IsLinux) {
        return "Linux"
    }
    elseif ($IsMacOS) {
        return "MacOS"
    }
    else {
        Write-Warning "Could not determine platform type. Defaulting to environment variable approach."
        return "Unknown"
    }
}

function Get-OpenRouterApiKey {
    <#
    .SYNOPSIS
        Retrieves the OpenRouter API key from the appropriate platform-specific secret store.
    .DESCRIPTION
        Detects the current platform and retrieves the OpenRouter API key from:
        - macOS: macOS keychain
        - Windows: Windows Credential Manager
        - Linux: Secret Service API (via secret-tool)
        - Any platform: Environment variable OPENROUTER_API_KEY as fallback
    .PARAMETER UseEnvironmentVariableOnly
        If set, bypasses all secret managers and uses only the environment variable.
    .EXAMPLE
        $apiKey = Get-OpenRouterApiKey
        # Retrieves API key from the appropriate platform-specific store
    .EXAMPLE
        $apiKey = Get-OpenRouterApiKey -UseEnvironmentVariableOnly
        # Retrieves API key from the environment variable only
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseEnvironmentVariableOnly
    )

    # Check environment variable first if explicitly requested
    if ($UseEnvironmentVariableOnly) {
        return Get-OpenRouterApiKeyFromEnvironment
    }

    # Determine the platform
    $platform = Get-PlatformType
    $apiKey = $null

    try {
        # Call the appropriate platform-specific function
        switch ($platform) {
            "Windows" {
                $apiKey = Get-OpenRouterApiKeyFromWindowsCredentialManager
            }
            "Linux" {
                $apiKey = Get-OpenRouterApiKeyFromLinuxSecretService
            }
            "MacOS" {
                $apiKey = Get-OpenRouterApiKeyFromMacOSKeychain
            }
            default {
                Write-Verbose "Unknown platform or platform detection failed. Falling back to environment variable."
                $apiKey = Get-OpenRouterApiKeyFromEnvironment
            }
        }
    }
    catch {
        Write-Verbose "Error retrieving API key from platform-specific store: $_"
    }

    # If we couldn't get the key from the platform-specific store, try environment variable
    if ([string]::IsNullOrEmpty($apiKey)) {
        Write-Verbose "Falling back to environment variable for API key"
        $apiKey = Get-OpenRouterApiKeyFromEnvironment
    }

    if ([string]::IsNullOrEmpty($apiKey)) {
        throw "API key not found in any available storage method. Please set it using Set-OpenRouterApiKey."
    }

    return $apiKey
}

function Get-OpenRouterApiKeyFromMacOSKeychain {
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
            Write-Verbose "API key not found in macOS keychain."
            return $null
        }
        
        return $apiKey
    }
    catch {
        Write-Verbose "Failed to retrieve API key from macOS keychain: $_"
        return $null
    }
}

function Get-OpenRouterApiKeyFromWindowsCredentialManager {
    <#
    .SYNOPSIS
        Retrieves the OpenRouter API key from the Windows Credential Manager.
    .DESCRIPTION
        Uses the Windows Credential Manager to retrieve the OpenRouter API key.
    #>
    [CmdletBinding()]
    param()

    try {
        # Check if CredentialManager module is available
        if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
            # Try importing module first in case it's installed but not loaded
            try {
                Import-Module CredentialManager -ErrorAction Stop
            }
            catch {
                Write-Verbose "CredentialManager module not found. Using native cmdlets."
                
                # Fall back to native Windows APIs
                $signature = @"
[DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

[DllImport("advapi32.dll", EntryPoint = "CredFree", SetLastError = true)]
public static extern void CredFree(IntPtr credential);

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
    public int Flags;
    public int Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize;
    public IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}
"@
                
                Add-Type -MemberDefinition $signature -Namespace Win32Utils -Name NativeMethods
                
                $credPointer = [IntPtr]::Zero
                $result = [Win32Utils.NativeMethods]::CredRead("OpenRouter", 1, 0, [ref]$credPointer)
                
                if ($result) {
                    $credential = [System.Runtime.InteropServices.Marshal]::PtrToStructure($credPointer, [Type][Win32Utils.NativeMethods+CREDENTIAL])
                    $passwordBytes = New-Object byte[] $credential.CredentialBlobSize
                    [System.Runtime.InteropServices.Marshal]::Copy($credential.CredentialBlob, $passwordBytes, 0, $credential.CredentialBlobSize)
                    $password = [System.Text.Encoding]::Unicode.GetString($passwordBytes)
                    [Win32Utils.NativeMethods]::CredFree($credPointer)
                    return $password
                }
                
                Write-Verbose "API key not found in Windows Credential Manager."
                return $null
            }
        }
        
        # Use CredentialManager module if available
        $cred = Get-StoredCredential -Target "OpenRouter"
        if ($cred) {
            return $cred.GetNetworkCredential().Password
        }
        
        Write-Verbose "API key not found in Windows Credential Manager."
        return $null
    }
    catch {
        Write-Verbose "Failed to retrieve API key from Windows Credential Manager: $_"
        return $null
    }
}

function Get-OpenRouterApiKeyFromLinuxSecretService {
    <#
    .SYNOPSIS
        Retrieves the OpenRouter API key from Linux secret managers.
    .DESCRIPTION
        Attempts to retrieve the OpenRouter API key from Linux secret managers 
        using secret-tool or other available tools.
    #>
    [CmdletBinding()]
    param()

    try {
        # Try secret-tool first (GNOME/Secret Service API)
        if (Get-Command "secret-tool" -ErrorAction SilentlyContinue) {
            $apiKey = secret-tool lookup service OpenRouter 2>$null
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                return $apiKey
            }
        }
        
        # Try pass (passwordstore.org) if available
        if (Get-Command "pass" -ErrorAction SilentlyContinue) {
            $apiKey = pass show OpenRouter 2>$null
            if (-not [string]::IsNullOrEmpty($apiKey)) {
                return $apiKey
            }
        }
        
        # If we can't find any secret managers, return null
        Write-Verbose "No compatible Linux secret manager found or API key not stored."
        return $null
    }
    catch {
        Write-Verbose "Failed to retrieve API key from Linux secret service: $_"
        return $null
    }
}

function Get-OpenRouterApiKeyFromEnvironment {
    <#
    .SYNOPSIS
        Retrieves the OpenRouter API key from environment variables.
    .DESCRIPTION
        Checks for the OPENROUTER_API_KEY environment variable.
    #>
    [CmdletBinding()]
    param()

    try {
        $apiKey = $env:OPENROUTER_API_KEY
        
        if ([string]::IsNullOrEmpty($apiKey)) {
            Write-Verbose "API key not found in environment variables."
            return $null
        }
        
        return $apiKey
    }
    catch {
        Write-Verbose "Failed to retrieve API key from environment variables: $_"
        return $null
    }
}

function Set-OpenRouterApiKey {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in the appropriate platform-specific secret store.
    .DESCRIPTION
        Detects the current platform and stores the OpenRouter API key in:
        - macOS: macOS keychain
        - Windows: Windows Credential Manager
        - Linux: Secret Service API (via secret-tool)
        - Any platform: Environment variable OPENROUTER_API_KEY as fallback
    .PARAMETER ApiKey
        The OpenRouter API key to store.
    .PARAMETER UseEnvironmentVariableOnly
        If set, bypasses all secret managers and uses only the environment variable.
    .PARAMETER Scope
        When using environment variables, specifies the scope. Valid values: "Process", "User", "Machine".
        Default is "Process".
    .EXAMPLE
        Set-OpenRouterApiKey -ApiKey "your-api-key-here"
        # Stores the API key in the appropriate platform-specific store
    .EXAMPLE
        Set-OpenRouterApiKey -ApiKey "your-api-key-here" -UseEnvironmentVariableOnly -Scope "User"
        # Stores the API key in the user's environment variables
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseEnvironmentVariableOnly,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Process", "User", "Machine")]
        [string]$Scope = "Process"
    )

    # Store in environment variable only if explicitly requested
    if ($UseEnvironmentVariableOnly) {
        return Set-OpenRouterApiKeyInEnvironment -ApiKey $ApiKey -Scope $Scope
    }

    # Determine the platform
    $platform = Get-PlatformType
    $success = $false

    try {
        # Call the appropriate platform-specific function
        switch ($platform) {
            "Windows" {
                $success = Set-OpenRouterApiKeyInWindowsCredentialManager -ApiKey $ApiKey
            }
            "Linux" {
                $success = Set-OpenRouterApiKeyInLinuxSecretService -ApiKey $ApiKey
            }
            "MacOS" {
                $success = Set-OpenRouterApiKeyInMacOSKeychain -ApiKey $ApiKey
            }
            default {
                Write-Warning "Unknown platform or platform detection failed. Falling back to environment variable."
                $success = Set-OpenRouterApiKeyInEnvironment -ApiKey $ApiKey -Scope $Scope
            }
        }
    }
    catch {
        Write-Verbose "Error storing API key in platform-specific store: $_"
        $success = $false
    }

    # If we couldn't store the key in the platform-specific store, try environment variable
    if (-not $success) {
        Write-Verbose "Falling back to environment variable for API key storage"
        $success = Set-OpenRouterApiKeyInEnvironment -ApiKey $ApiKey -Scope $Scope
    }

    if (-not $success) {
        throw "Failed to store API key in any available storage method."
    }

    return $success
}

function Set-OpenRouterApiKeyInMacOSKeychain {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in the macOS keychain.
    .DESCRIPTION
        Uses the security command on macOS to store the OpenRouter API key
        in the keychain, creating a new entry or updating an existing one.
    .PARAMETER ApiKey
        The OpenRouter API key to store.
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
            return $true
        } else {
            Write-Error "Failed to store API key: $result"
            return $false
        }
    }
    catch {
        Write-Error "Failed to store API key in macOS keychain: $_"
        return $false
    }
}

function Set-OpenRouterApiKeyInWindowsCredentialManager {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in the Windows Credential Manager.
    .DESCRIPTION
        Uses the Windows Credential Manager to store the OpenRouter API key.
    .PARAMETER ApiKey
        The OpenRouter API key to store.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    try {
        # Check if CredentialManager module is available
        if (-not (Get-Module -ListAvailable -Name CredentialManager)) {
            # Try importing module first in case it's installed but not loaded
            try {
                Import-Module CredentialManager -ErrorAction Stop
            }
            catch {
                Write-Verbose "CredentialManager module not found. Using native cmdlets."
                
                # Fall back to native Windows APIs
                $signature = @"
[DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool CredWrite(ref CREDENTIAL credential, int flags);

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CREDENTIAL {
    public int Flags;
    public int Type;
    public string TargetName;
    public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize;
    public IntPtr CredentialBlob;
    public int Persist;
    public int AttributeCount;
    public IntPtr Attributes;
    public string TargetAlias;
    public string UserName;
}
"@
                Add-Type -MemberDefinition $signature -Namespace Win32Utils -Name NativeMethods
                
                $credStruct = New-Object Win32Utils.NativeMethods+CREDENTIAL
                $credStruct.Type = 1  # CRED_TYPE_GENERIC
                $credStruct.TargetName = "OpenRouter"
                $credStruct.UserName = [Environment]::UserName
                $credStruct.Comment = "OpenRouter API Key"
                $credStruct.Persist = 2  # CRED_PERSIST_LOCAL_MACHINE
                
                $passwordBytes = [System.Text.Encoding]::Unicode.GetBytes($ApiKey)
                $credStruct.CredentialBlobSize = $passwordBytes.Length
                $credStruct.CredentialBlob = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($passwordBytes.Length)
                [System.Runtime.InteropServices.Marshal]::Copy($passwordBytes, 0, $credStruct.CredentialBlob, $passwordBytes.Length)
                
                $result = [Win32Utils.NativeMethods]::CredWrite([ref]$credStruct, 0)
                [System.Runtime.InteropServices.Marshal]::FreeHGlobal($credStruct.CredentialBlob)
                
                if ($result) {
                    Write-Host "OpenRouter API key has been successfully stored in Windows Credential Manager." -ForegroundColor Green
                    return $true
                } else {
                    $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    Write-Error "Failed to store API key in Windows Credential Manager. Error code: $errorCode"
                    return $false
                }
            }
        }
        
        # Use CredentialManager module if available
        $secureString = ConvertTo-SecureString $ApiKey -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential("OpenRouter", $secureString)
        New-StoredCredential -Target "OpenRouter" -Credential $cred -Persist LocalMachine | Out-Null
        
        Write-Host "OpenRouter API key has been successfully stored in Windows Credential Manager." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to store API key in Windows Credential Manager: $_"
        return $false
    }
}

function Set-OpenRouterApiKeyInLinuxSecretService {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in Linux secret managers.
    .DESCRIPTION
        Attempts to store the OpenRouter API key in Linux secret managers 
        using secret-tool or other available tools.
    .PARAMETER ApiKey
        The OpenRouter API key to store.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )

    try {
        # Try secret-tool first (GNOME/Secret Service API)
        if (Get-Command "secret-tool" -ErrorAction SilentlyContinue) {
            $result = $ApiKey | secret-tool store --label="OpenRouter API Key" service OpenRouter 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OpenRouter API key has been successfully stored using secret-tool." -ForegroundColor Green
                return $true
            }
        }
        
        # Try pass (passwordstore.org) if available
        if (Get-Command "pass" -ErrorAction SilentlyContinue) {
            $result = $ApiKey | pass insert -f OpenRouter 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "OpenRouter API key has been successfully stored using pass." -ForegroundColor Green
                return $true
            }
        }
        
        # If we can't find any secret managers, return false
        Write-Warning "No compatible Linux secret manager found. Consider using environment variables instead."
        return $false
    }
    catch {
        Write-Error "Failed to store API key in Linux secret service: $_"
        return $false
    }
}

function Set-OpenRouterApiKeyInEnvironment {
    <#
    .SYNOPSIS
        Stores the OpenRouter API key in environment variables.
    .DESCRIPTION
        Sets the OPENROUTER_API_KEY environment variable in the specified scope.
    .PARAMETER ApiKey
        The OpenRouter API key to store.
    .PARAMETER Scope
        Specifies the scope of the environment variable. Valid values: "Process", "User", "Machine".
        Default is "Process".
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ApiKey,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Process", "User", "Machine")]
        [string]$Scope = "Process"
    )

    try {
        # Set the environment variable based on the scope
        switch ($Scope) {
            "Process" {
                $env:OPENROUTER_API_KEY = $ApiKey
            }
            "User" {
                [System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $ApiKey, "User")
                # Also set it for the current process
                $env:OPENROUTER_API_KEY = $ApiKey
            }
            "Machine" {
                [System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", $ApiKey, "Machine")
                # Also set it for the current process
                $env:OPENROUTER_API_KEY = $ApiKey
            }
        }
        
        Write-Host "OpenRouter API key has been successfully stored in the $Scope environment variable." -ForegroundColor Green
        
        if ($Scope -ne "Process") {
            Write-Host "Note: You may need to restart your session for the environment variable to take effect in all applications." -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to store API key in environment variables: $_"
        return $false
    }
}

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

# Module variable to store the default LLM model
$script:DefaultLLMModel = "deepseek/deepseek-chat-v3-0324:free"


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

function Get-ImageAltText {
    <#
    .SYNOPSIS
        Generates descriptive alt text for an image using an LLM.
    .DESCRIPTION
        Uploads an image to the OpenRouter API and uses an LLM (by default Claude 3.7 Sonnet)
        to generate descriptive alt text. The function returns the alt text and optionally
        copies it to the clipboard.
    .PARAMETER ImagePath
        The path to the image file to analyze. 
        This parameter can be used positionally (without specifying -ImagePath).
    .PARAMETER Model
        The LLM model to use. Defaults to "anthropic/claude-3.7-sonnet".
    .PARAMETER CopyToClipboard
        If set, copies the generated alt text to the clipboard (uses platform-specific clipboard commands).
    .EXAMPLE
        Get-ImageAltText "./my_image.jpg"
        # Generates alt text for the specified image using positional parameter
    .EXAMPLE
        Get-ImageAltText -ImagePath "./my_image.jpg"
        # Same as above but with explicit parameter name
    .EXAMPLE
        Get-ImageAltText "./screenshot.png" -CopyToClipboard
        # Generates alt text and copies it to the clipboard
    .EXAMPLE
        Get-ImageAltText "./photo.jpg" -Model "anthropic/claude-3-opus"
        # Uses Claude 3 Opus model for potentially more detailed description
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$ImagePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Model = "anthropic/claude-3.7-sonnet",
        
        [Parameter(Mandatory = $false)]
        [switch]$CopyToClipboard = $false
    )
    
    process {
        try {
            # Verify the image file exists
            if (-not (Test-Path -Path $ImagePath)) {
                throw "Image file not found: $ImagePath"
            }
            
            # Convert the image to a base64 string
            $base64Image = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ImagePath))
            
            # Get the file extension and determine the MIME type
            $extension = [System.IO.Path]::GetExtension($ImagePath).ToLower()
            $contentType = switch ($extension) {
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".png"  { "image/png" }
                ".gif"  { "image/gif" }
                ".webp" { "image/webp" }
                ".svg"  { "image/svg+xml" }
                default { "application/octet-stream" }
            }
            
            # Format the base64 string with content-type prefix
            $base64ImageWithPrefix = "data:$contentType;base64,$base64Image"
            
            # Get the API key using the module's function
            $apiKey = Get-OpenRouterApiKey
            
            # Instruction string for alt text generation
            $instructionString = "You write alt text for any image pasted in by the user. Alt text is always presented in a fenced code block to make it easy to copy and paste out. It is always presented on a single line so it can be used easily in Markdown images. All text on the image (for screenshots etc) must be exactly included. A short note describing the nature of the image itself should go first. Any quotation marks or other punctuation needs to be cancelled out."
            
            # Prepare headers and request body
            $requestHeaders = @{
                "Content-Type" = "application/json"
                "Authorization" = "Bearer $apiKey"
                "HTTP-Referer" = "https://localhost" # Required by OpenRouter
                "X-Title" = "PowerShell OpenRouter Module" # Optional but recommended
            }
            
            $requestBody = @{
                "model" = $Model
                "messages" = @(
                    @{
                        "role" = "user"
                        "content" = @(
                            @{
                                "type" = "text"
                                "text" = $instructionString
                            }
                            @{
                                "type" = "image_url"
                                "image_url" = @{
                                    "url" = $base64ImageWithPrefix
                                }
                            }
                        )
                    }
                )
            }
            
            # Convert the hashtable to JSON
            $requestBodyJson = $requestBody | ConvertTo-Json -Depth 10
            
            Write-Verbose "Sending image to OpenRouter API using model: $Model"
            
            # Send the request
            $response = Invoke-RestMethod -Method Post -Uri "https://openrouter.ai/api/v1/chat/completions" -Headers $requestHeaders -Body $requestBodyJson
            
            # Extract the alt text from the response
            $altText = $response.choices[0].message.content
            
            # Copy to clipboard if requested
            if ($CopyToClipboard) {
                $platform = Get-PlatformType
                
                if ($platform -eq "MacOS" -and (Get-Command "pbcopy" -ErrorAction SilentlyContinue)) {
                    $altText | pbcopy
                    Write-Host "Alt text copied to clipboard" -ForegroundColor Green
                } elseif ($platform -eq "Windows") {
                    # Check if Set-Clipboard is available (PowerShell 5+)
                    if (Get-Command "Set-Clipboard" -ErrorAction SilentlyContinue) {
                        $altText | Set-Clipboard
                        Write-Host "Alt text copied to clipboard" -ForegroundColor Green
                    } else {
                        Write-Warning "Set-Clipboard cmdlet not available. Install PowerShell 5+ or the ClipboardText module."
                    }
                } elseif ($platform -eq "Linux" -and (Get-Command "xclip" -ErrorAction SilentlyContinue)) {
                    $altText | xclip -selection clipboard
                    Write-Host "Alt text copied to clipboard" -ForegroundColor Green
                } else {
                    Write-Warning "Clipboard functionality not available on this platform"
                }
            }
            
            # Return the alt text
            return $altText
        }
        catch {
            Write-Error "Error generating alt text: $_"
            return $null
        }
    }
}

# Export the public functions
Export-ModuleMember -Function New-LLMRequest, Set-OpenRouterApiKey, Set-DefaultLLM, Get-DefaultLLM, Get-PlatformType, Set-OpenRouterApiKeyInEnvironment, Get-ImageAltText