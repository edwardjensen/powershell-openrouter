<#
.SYNOPSIS
    API key management functions for the OpenRouterPS module.
.DESCRIPTION
    Contains functions for storing and retrieving the OpenRouter API key
    from various platform-specific secure storage locations.
#>

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