$ErrorActionPreference = "Stop"

$siteRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$rootPrefix = $siteRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$baseUrl = "http://127.0.0.1:8765/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($baseUrl)

try {
    $listener.Start()
} catch {
    Write-Error "Could not start the local website server at $baseUrl. The address may already be in use. $($_.Exception.Message)"
    exit 1
}

Write-Host "Serving AniStream at $baseUrl"
Write-Host "This server is only available on this computer. Close this window to stop it."
try {
    Start-Process "$($baseUrl)index.html"
} catch {
    Write-Error "The server is running, but the browser could not be opened automatically. Visit $($baseUrl)index.html. $($_.Exception.Message)"
}

$contentTypes = @{
    ".css" = "text/css; charset=utf-8"
    ".html" = "text/html; charset=utf-8"
    ".ico" = "image/x-icon"
    ".jpeg" = "image/jpeg"
    ".jpg" = "image/jpeg"
    ".js" = "text/javascript; charset=utf-8"
    ".json" = "application/manifest+json; charset=utf-8"
    ".png" = "image/png"
    ".svg" = "image/svg+xml"
    ".webp" = "image/webp"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch {
        if ($listener.IsListening) {
            Write-Error "The local website server stopped accepting requests. $($_.Exception.Message)"
        }
        break
    }

    $response = $context.Response
    try {
        if ($context.Request.HttpMethod -ne "GET" -and $context.Request.HttpMethod -ne "HEAD") {
            $response.StatusCode = 405
            $response.Headers["Allow"] = "GET, HEAD"
        } else {
            $requestPath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))
            if ([string]::IsNullOrEmpty($requestPath)) {
                $requestPath = "index.html"
            }

            $filePath = [System.IO.Path]::GetFullPath((Join-Path $siteRoot $requestPath))
            if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $response.StatusCode = 403
            } else {
                $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                if (-not $contentTypes.ContainsKey($extension)) {
                    $response.StatusCode = 403
                } elseif (-not [System.IO.File]::Exists($filePath)) {
                    $response.StatusCode = 404
                } else {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $response.StatusCode = 200
                    $response.ContentType = $contentTypes[$extension]
                    $response.ContentLength64 = $bytes.Length
                    $response.Headers["X-Content-Type-Options"] = "nosniff"
                    $response.Headers["Cache-Control"] = "no-cache"
                    if ($context.Request.HttpMethod -eq "GET") {
                        $response.OutputStream.Write($bytes, 0, $bytes.Length)
                    }
                }
            }
        }
    } catch {
        Write-Error "Failed to serve a request for $($context.Request.RawUrl). $($_.Exception.Message)"
        $response.StatusCode = 500
    } finally {
        $response.Close()
    }
}

$listener.Close()
