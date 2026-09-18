param(
    [string]$Repo = (Split-Path -Parent $PSScriptRoot)
)

# =============================================================
#  bump-assets.ps1 -- refresh the "?v=" cache-busting token
# -------------------------------------------------------------
#  index.html links three local assets:
#     css/style.css
#     js/gallery-data.js
#     js/main.js
#  GitHub Pages always answers with "Cache-Control: max-age=600"
#  and IGNORES this project's _headers file, so after a push a
#  browser may keep using the old css/js for up to ten minutes.
#  Changing the URL is the only reliable way to force a fresh
#  download, so those three references carry a "?v=" token that
#  is derived from the content of the three files.
#
#  Run it before every commit that touches css/ or js/:
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bump-assets.ps1
#
#  It is idempotent: running it twice changes nothing.
# =============================================================

$ErrorActionPreference = 'Stop'
Set-Location $Repo

$targets = @('css/style.css', 'js/gallery-data.js', 'js/main.js')
$index = 'index.html'

foreach ($t in $targets) {
    if (-not (Test-Path $t)) { throw "cannot stamp a missing file: $t" }
}
if (-not (Test-Path $index)) { throw "index.html not found in $Repo" }

# One shared token for all three files: any edit to any of them
# invalidates the whole set (simple and easy to reason about).
$joined = New-Object System.Text.StringBuilder
foreach ($t in $targets) {
    [void]$joined.Append((Get-FileHash -Algorithm SHA256 -Path $t).Hash)
}

$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined.ToString())
    $hex = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLower()
}
finally {
    $sha.Dispose()
}

$token = (Get-Date -Format 'yyyyMMdd') + '-' + $hex.Substring(0, 10)

# UTF-8 without BOM; ReadAllText/WriteAllText keep the existing line endings
$html = [System.IO.File]::ReadAllText($index, [System.Text.Encoding]::UTF8)

$found = [System.Text.RegularExpressions.Regex]::Matches($html, '\?v=([0-9A-Za-z._-]+)')
if ($found.Count -gt 0) {
    $old = $found[0].Groups[1].Value
    if ($old -eq $token) {
        Write-Output "already up to date: ?v=$token (3 references)"
        return
    }
    $html = $html.Replace('?v=' + $old, '?v=' + $token)
}
else {
    # Build the stamped reference explicitly: nested @() literals that mix
    # commas with + are parsed surprisingly by PowerShell 5.1, so keep it flat.
    $keys = @(
        'href="css/style.css"',
        'src="js/gallery-data.js"',
        'src="js/main.js"'
    )
    foreach ($key in $keys) {
        if ($html.IndexOf($key) -lt 0) {
            throw "index.html no longer contains $key -- update bump-assets.ps1"
        }
        # every key ends with the closing quote -> insert ?v=<token> before it
        $stampedRef = $key.Substring(0, $key.Length - 1) + '?v=' + $token + '"'
        $html = $html.Replace($key, $stampedRef)
    }
}

[System.IO.File]::WriteAllText($index, $html, (New-Object System.Text.UTF8Encoding $false))

$count = [System.Text.RegularExpressions.Regex]::Matches(
    $html, '\?v=' + [System.Text.RegularExpressions.Regex]::Escape($token)).Count
Write-Output "stamped $count reference(s) with ?v=$token"
