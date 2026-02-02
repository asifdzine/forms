$targetWidth = 793.7
$files = Get-ChildItem "d:\OurProjects\forms\*.html" | Where-Object { $_.Name -notmatch "Email" -and $_.Name -notmatch "process_forms" }

foreach ($file in $files) {
    Write-Host "Processing $($file.Name)..."
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    # 1. Zoom
    $zoom = "1"
    # match id="page1" ... width: Npx
    # Simplified regex using single quotes for the string
    # We use a variable for regex to keep it clean
    $pattern = 'id=["'']page\d+["''].*?width:\s*(\d+)px' 
    
    if ($content -match $pattern) {
        $width = [double]$matches[1]
        if ($width -gt 0) { $zoom = "{0:N4}" -f ($targetWidth / $width) }
    }
    
    # 2. CSS
    $css = @"
<style media="print">
	@page { size: A4; margin: 0; }
	html, body { width: 210mm; height: 297mm; min-width: 210mm; margin: 0; padding: 0; background-color: white; }
	#formviewer, #contentContainer, form { width: 100%; margin: 0; padding: 0; }
	.page { margin: 0 !important; border: none !important; box-shadow: none !important; zoom: $zoom; page-break-after: always; page-break-inside: avoid; overflow: hidden !important; }
	.page:last-child { page-break-after: auto; }
	#overlay { display: none !important; }
	* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
</style>
"@

    # 3. Clean/Inject CSS
    # Remove old print style block
    $content = [Regex]::Replace($content, '(?s)<style media="print">.*?</style>\s*', '')
    
    if ($content -match '</head>') {
        $content = $content -replace '</head>', "$css`n</head>"
    } else {
        $content += $css
    }

    # 4. Input value=""
    # Check for inputs with type image
    $content = [Regex]::Replace($content, '<input[^>]+type=["'']image["''][^>]*>', { param($m)
        $txt = $m.Value
        if ($txt -notmatch 'value=') {
            if ($txt -match '/>$') { return $txt -replace '/>$', ' value="" />' }
            else { return $txt -replace '>$', ' value="">' }
        }
        return $txt
    })
    
    # 5. Minify
    # Remove HTML comments
    $content = [Regex]::Replace($content, '<!--.*?-->', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    # Minify CSS content inside <style> tags
    $content = [Regex]::Replace($content, '(?s)<style[^>]*>(.*?)</style>', { 
        param($match)
        $css = $match.Groups[1].Value
        # Remove CSS comments
        $css = [Regex]::Replace($css, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        # Replace newlines and multiple spaces with single space
        $css = [Regex]::Replace($css, '\s+', ' ')
        # Remove spaces around delimiters { } : ; ,
        $css = [Regex]::Replace($css, '\s*([{}:;,])\s*', '$1')
        # Return reconstructed style tag
        return "<style type=""text/css"">$css</style>"
    })

    # Collapse whitespace between HTML tags
    $content = [Regex]::Replace($content, '>\s+<', '><')
    
    Set-Content -Path $file.FullName -Value $content -Encoding UTF8
}
