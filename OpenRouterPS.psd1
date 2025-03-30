@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'OpenRouterPS.psm1'
    
    # Version number of this module.
    ModuleVersion = '0.1.0'
    
    # ID used to uniquely identify this module
    GUID = '161a4efb-d65a-4a61-93d8-5c001008fa50'

    # Author of this module
    Author = 'Edward Jensen'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 Edward Jensen. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'A PowerShell module for making requests to the OpenRouter API, which allows access to various large language models.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-PlatformType',
        'Get-OpenRouterApiKey',
        'Set-OpenRouterApiKey',
        'Set-OpenRouterApiKeyInEnvironment',
        'New-LLMRequest',
        'Set-DefaultLLM',
        'Get-DefaultLLM',
        'Get-ImageAltText'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('OpenRouter', 'API', 'AI', 'LLM', 'GPT')
            
            # A URL to the license for this module.
            LicenseUri = 'https://github.com/edwardjensen/OpenRouterPS/blob/main/LICENSE'
            
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/edwardjensen/OpenRouterPS'
            
            # A URL to an icon representing this module.
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of the OpenRouterPS module.'
        }
    }
}