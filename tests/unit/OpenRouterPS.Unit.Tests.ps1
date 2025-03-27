BeforeAll {
    # Import the module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "../../OpenRouterPS.psm1"
    Import-Module $ModulePath -Force
    
    # Mock functions for platform-specific operations
    function global:Get-PlatformType { return "MacOS" }
    
    # Mock security command for macOS keychain
    function global:security {
        param($cmd, $param1, $param2, $param3)
        if ($cmd -eq 'find-generic-password' -and $param1 -eq '-s' -and $param2 -eq 'OpenRouter' -and $param3 -eq '-w') {
            return "test-api-key-12345"
        }
        return $null
    }
}

Describe "Platform Detection Tests" {
    It "Correctly identifies the current platform" {
        # Mock the environment variables
        $script:IsWindows = $false
        $script:IsLinux = $false
        $script:IsMacOS = $true
        
        $result = Get-PlatformType
        $result | Should -Be "MacOS"
    }
}

Describe "API Key Management Tests" {
    Context "macOS Keychain" {
        It "Gets API key from macOS keychain" {
            # Setup
            Mock security { return "test-api-key-12345" }
            
            # Test
            $result = Get-OpenRouterApiKeyFromMacOSKeychain
            
            # Verify
            $result | Should -Be "test-api-key-12345"
        }

        It "Handles missing API key from macOS keychain" {
            # Setup
            Mock security { return $null }
            
            # Test
            $result = Get-OpenRouterApiKeyFromMacOSKeychain
            
            # Verify
            $result | Should -BeNullOrEmpty
        }
    }
    
    Context "Environment Variables" {
        It "Gets API key from environment variable" {
            # Setup
            $env:OPENROUTER_API_KEY = "test-api-key-env"
            
            # Test
            $result = Get-OpenRouterApiKeyFromEnvironment
            
            # Verify
            $result | Should -Be "test-api-key-env"
            
            # Cleanup
            $env:OPENROUTER_API_KEY = $null
        }
        
        It "Handles missing environment variable" {
            # Setup
            $env:OPENROUTER_API_KEY = $null
            
            # Test
            $result = Get-OpenRouterApiKeyFromEnvironment
            
            # Verify
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Default LLM Model Tests" {
    It "Sets and gets default LLM model" {
        # Test setting default model
        Set-DefaultLLM -Model "test-model/test-version"
        
        # Verify model was set correctly
        $result = Get-DefaultLLM
        $result | Should -Be "test-model/test-version"
    }
}

Describe "API Request Tests" {
    Context "Request Formation" {
        It "Forms a valid API request body" {
            # This is a more complex test that would need to mock Invoke-RestMethod
            # Here's a simplified version:
            
            Mock Invoke-RestMethod {
                param($Uri, $Method, $Headers, $Body)
                
                # Parse the body to check it
                $bodyObj = $Body | ConvertFrom-Json
                
                # Return a test response
                return @{
                    choices = @(
                        @{
                            message = @{
                                content = "Test response content"
                            }
                        }
                    )
                }
            }
            
            Mock Get-OpenRouterApiKey { return "test-api-key" }
            
            # Call the function
            $result = New-LLMRequest -Model "test-model" -Prompt "Test prompt" -ReturnFull
            
            # Assertions
            $result.choices[0].message.content | Should -Be "Test response content"
            
            # Verify the mock was called with correct parameters
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Method -eq "Post" -and
                $Uri -eq "https://openrouter.ai/api/v1/chat/completions" -and
                $Body -like "*test-model*" -and
                $Body -like "*Test prompt*"
            }
        }
    }
}
