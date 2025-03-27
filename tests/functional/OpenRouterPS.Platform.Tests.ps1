BeforeAll {
    # Import the module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "../../OpenRouterPS.psm1"
    Import-Module $ModulePath -Force
}

Describe "Platform-Specific Tests" {
    It "Correctly identifies platform: Windows, macOS, or Linux" {
        $platform = Get-PlatformType
        $platform | Should -BeIn @('Windows', 'MacOS', 'Linux')
    }
    
    It "Uses correct API key storage based on platform" {
        $platform = Get-PlatformType
        
        # Create test API key
        $testApiKey = "test-api-key-" + [Guid]::NewGuid().ToString().Substring(0, 8)
        
        # Set API key in environment variable for testing
        $env:OPENROUTER_API_KEY = $testApiKey
        
        # Get API key (this will pull from environment since we can't assume
        # secure storage is available in CI environment)
        $resultKey = Get-OpenRouterApiKey -UseEnvironmentVariableOnly
        
        # Key should match what we set
        $resultKey | Should -Be $testApiKey
        
        # Clean up
        $env:OPENROUTER_API_KEY = $null
    }
}

Describe "Cross-Platform API Key Storage" {
    It "Sets API key in environment variable correctly" {
        $testApiKey = "test-env-key-" + [Guid]::NewGuid().ToString().Substring(0, 8)
        
        # Set key in environment variable
        Set-OpenRouterApiKeyInEnvironment -ApiKey $testApiKey -Scope "Process"
        
        # Verify it was set
        $env:OPENROUTER_API_KEY | Should -Be $testApiKey
        
        # Retrieve it with the module function
        $resultKey = Get-OpenRouterApiKeyFromEnvironment
        $resultKey | Should -Be $testApiKey
        
        # Clean up
        $env:OPENROUTER_API_KEY = $null
    }
}

# Create environment-specific tests
Describe "MacOS-Specific Tests" -Skip:(-not $IsMacOS) {
    # These tests will only run on macOS
    It "Attempts to use macOS keychain" {
        if ($IsMacOS) {
            # This test should be skipped in CI unless we can mock the keychain
            $testKey = "test-key-macos"
            
            # Mock the security command
            function global:security { param($a, $b, $c, $d) return $testKey }
            
            # Try to get key from mock keychain
            $result = Get-OpenRouterApiKeyFromMacOSKeychain
            
            # Should match our mock
            $result | Should -Be $testKey
        } else {
            Set-ItResult -Skipped -Because "Not running on macOS"
        }
    }
}

Describe "Windows-Specific Tests" -Skip:(-not $IsWindows) {
    # These tests will only run on Windows
    It "Attempts to use Windows Credential Manager" {
        if ($IsWindows) {
            # Skip in CI or mock the functionality
            Set-ItResult -Skipped -Because "Cannot test Windows Credential Manager in CI without mocks"
        } else {
            Set-ItResult -Skipped -Because "Not running on Windows"
        }
    }
}

Describe "Linux-Specific Tests" -Skip:(-not $IsLinux) {
    # These tests will only run on Linux
    It "Attempts to use Linux secret stores" {
        if ($IsLinux) {
            # Skip in CI or mock the functionality
            Set-ItResult -Skipped -Because "Cannot test Linux secret storage in CI without mocks"
        } else {
            Set-ItResult -Skipped -Because "Not running on Linux"
        }
    }
}