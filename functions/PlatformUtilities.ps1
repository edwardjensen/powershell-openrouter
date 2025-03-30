<#
.SYNOPSIS
    Platform detection utilities for the OpenRouterPS module.
.DESCRIPTION
    Contains functions for detecting the operating system platform.
#>

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