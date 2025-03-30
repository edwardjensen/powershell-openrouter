<#
.SYNOPSIS
    Image-related functions for the OpenRouterPS module.
.DESCRIPTION
    Contains functions for working with images via the OpenRouter API.
#>

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