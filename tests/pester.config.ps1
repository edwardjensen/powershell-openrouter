#!/usr/bin/env pwsh
# Create test directory structure for OpenRouterPS module

# Define paths
$testRoot = "./tests"
$unitTestPath = "$testRoot/Unit"
$integrationTestPath = "$testRoot/Integration"
$functionalTestPath = "$testRoot/Functional"

# Create directories
New-Item -ItemType Directory -Path $unitTestPath -Force
New-Item -ItemType Directory -Path $integrationTestPath -Force
New-Item -ItemType Directory -Path $functionalTestPath -Force

# Copy test files to appropriate directories (assuming you've created them elsewhere)
Copy-Item "./Unit-Tests.ps1" -Destination "$unitTestPath/OpenRouterPS.Unit.Tests.ps1" -Force
Copy-Item "./Integration-Tests.ps1" -Destination "$integrationTestPath/OpenRouterPS.Integration.Tests.ps1" -Force
Copy-Item "./Platform-Tests.ps1" -Destination "$functionalTestPath/OpenRouterPS.Platform.Tests.ps1" -Force

# Create a Pester configuration file at the root of the test directory
$pesterConfigContent = @'
@{
    Run = @{
        Path = "./tests"
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = './OpenRouterPS.psm1'
        OutputPath = './coverage.xml'
        OutputFormat = 'JaCoCo'
    }
}
'@

Set-Content -Path "$testRoot/pester.config.ps1" -Value $pesterConfigContent

Write-Host "Test directory structure created successfully!" -ForegroundColor Green
Write-Host "Unit Tests: $unitTestPath" -ForegroundColor Cyan
Write-Host "Integration Tests: $integrationTestPath" -ForegroundColor Cyan
Write-Host "Functional Tests: $functionalTestPath" -ForegroundColor Cyan
