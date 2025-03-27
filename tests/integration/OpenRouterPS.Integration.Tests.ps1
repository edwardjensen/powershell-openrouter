BeforeAll {
    # Import the module
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath "../../OpenRouterPS.psm1"
    Import-Module $ModulePath -Force
    
    # Set API key from environment variable for tests
    # This is set by GitHub Actions secrets
    if ($env:OPENROUTER_API_KEY) {
        Set-OpenRouterApiKeyInEnvironment -ApiKey $env:OPENROUTER_API_KEY
    } else {
        Write-Warning "OPENROUTER_API_KEY environment variable not set. Some tests may fail."
    }
}

Describe "OpenRouter API Integration Tests" {
    # Skip all tests if no API key is available
    BeforeAll {
        $apiKey = $env:OPENROUTER_API_KEY
        if (-not $apiKey) {
            Set-ItResult -Inconclusive -Because "No API key available for testing"
        }
    }
    
    It "Successfully retrieves API key from environment" {
        $apiKey = Get-OpenRouterApiKey -UseEnvironmentVariableOnly
        $apiKey | Should -Not -BeNullOrEmpty
    }
    
    It "Sets default model" {
        Set-DefaultLLM -Model "deepseek/deepseek-chat-v3-0324:free"
        $model = Get-DefaultLLM
        $model | Should -Be "deepseek/deepseek-chat-v3-0324:free"
    }
    
    It "Makes a basic API request" {
        $prompt = "Say 'Hello, this is a test' and nothing else."
        $response = New-LLMRequest -Prompt $prompt -MaxTokens 20
        
        # The response should contain our expected phrase
        $response | Should -Match "Hello, this is a test"
    }
    
    It "Handles errors with invalid model gracefully" {
        # This should throw an error because the model doesn't exist
        {
            New-LLMRequest -Model "nonexistent-model" -Prompt "Test" -ErrorAction Stop
        } | Should -Throw
    }
}

Describe "Streaming API Tests" {
    # Skip all tests if no API key is available
    BeforeAll {
        $apiKey = $env:OPENROUTER_API_KEY
        if (-not $apiKey) {
            Set-ItResult -Inconclusive -Because "No API key available for testing"
        }
    }
    
    It "Successfully streams a response" {
        # Capture output
        $output = $null
        $output = New-LLMRequest -Prompt "Count from 1 to 5." -Stream -Return -MaxTokens 20
        
        # Output should contain numbers 1 through 5
        $output | Should -Match "1"
        $output | Should -Match "2"
        $output | Should -Match "3"
        $output | Should -Match "4"
        $output | Should -Match "5"
    }
    
    It "Writes to output file" {
        $testFile = Join-Path $TestDrive "test_output.md"
        New-LLMRequest -Prompt "Write a single line: 'Test successful'." -OutFile $testFile -MaxTokens 20
        
        # File should exist and contain our test text
        Test-Path $testFile | Should -Be $true
        Get-Content $testFile | Should -Match "Test successful"
    }
}