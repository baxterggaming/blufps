# Publishes the files in dist\ to GitHub so every installed bluFPS can update itself - nobody has to download anything.
# Two destinations: Testing (your own repo while you build) and Customers (the repo your customers update from).
param([string]$Target = '', [switch]$Auto)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    $root = Split-Path $PSScriptRoot -Parent
    $dist = Join-Path $root 'dist'
    $ver = [regex]::Match((Get-Content (Join-Path $root 'app\bluFPS.ps1') -Raw), "AppVersion = '([\d.]+)'").Groups[1].Value
    $zip = Join-Path $dist "bluFPS-v$ver-update.zip"
    $exe = Join-Path $dist "bluFPS-v$ver-Setup.exe"
    $macZip = Join-Path $dist "bluFPS-v$ver-Mac.zip"
    if (-not (Test-Path $zip)) { Write-Host "Run BUILD.bat first (could not find $zip)." -ForegroundColor Yellow; return }

    $cfgDir = Join-Path $env:APPDATA 'bluFPS'; New-Item $cfgDir -ItemType Directory -Force | Out-Null
    $cfgPath = Join-Path $cfgDir 'publish.json'
    $all = @{ Active = 'Testing'; Targets = @{} }
    if (Test-Path $cfgPath) {
        try {
            $j = Get-Content $cfgPath -Raw | ConvertFrom-Json
            if ($j.Targets) {
                foreach ($p in $j.Targets.PSObject.Properties) { if ($p.Value.User -and $p.Value.Token) { $all.Targets[$p.Name] = $p.Value } }
                if ($j.Active) { $all.Active = "$($j.Active)" }
            } elseif ($j.User -and $j.Token) { $all.Targets['Testing'] = $j }
        } catch {}
    }
    function Save-All { ([pscustomobject]@{ Active = $all.Active; Targets = $all.Targets } | ConvertTo-Json -Depth 5) | Set-Content $cfgPath }
    function New-Target($label) {
        Write-Host ''; Write-Host "Set up the $label destination (asked only once)" -ForegroundColor Cyan
        Write-Host '1. A free account at https://github.com (a different account or repository for customers is fine)'
        Write-Host '2. A token: https://github.com/settings/tokens > Generate new token (classic) > tick "public_repo" > Generate'
        Write-Host ''
        $u = (Read-Host "GitHub username for $label").Trim()
        $defRepo = 'blufps'; if ($label -eq 'Customers') { $defRepo = 'blufps-releases' }
        $r = (Read-Host "Repository name for $label (press Enter for $defRepo)").Trim(); if (-not $r) { $r = $defRepo }
        $sec = Read-Host "Paste the token for $label (stored encrypted, for your Windows account only)" -AsSecureString
        $pm = (Read-Host "Also keep the repository's main branch up to date with the program files and a README? (Y/n)").Trim()
        return [pscustomobject]@{ User = $u; Repo = $r; Token = (ConvertFrom-SecureString $sec); PushMain = ($pm -notmatch '^[nN]') }
    }
    $names = @('Testing', 'Customers')
    $chosen = $null
    if ($Target -and ($names -contains $Target)) { $chosen = $Target }
    elseif ($Auto -and $all.Targets.ContainsKey($all.Active)) { $chosen = $all.Active }
    elseif ($all.Targets.Count -eq 0) { $chosen = 'Testing'; Write-Host 'No destination yet - setting up your TESTING destination first.' }
    else {
        Write-Host ''; Write-Host 'Where do you want to publish?' -ForegroundColor Cyan
        $n = 1
        foreach ($nm in $names) { $t = $all.Targets[$nm]; $desc = '(not set up yet)'; if ($t) { $desc = "github.com/$($t.User)/$($t.Repo)" }; Write-Host "  $n = $nm   $desc"; $n++ }
        $ans = (Read-Host "Type 1 or 2 (press Enter for $($all.Active))").Trim()
        if ($ans -eq '1') { $chosen = 'Testing' } elseif ($ans -eq '2') { $chosen = 'Customers' } else { $chosen = $all.Active }
    }
    if (-not $all.Targets.ContainsKey($chosen)) { $all.Targets[$chosen] = New-Target $chosen }
    $all.Active = $chosen; Save-All
    $cfg = $all.Targets[$chosen]
    if ($chosen -eq 'Customers') {
        $yes = (Read-Host "You are publishing v$ver to CUSTOMERS (github.com/$($cfg.User)/$($cfg.Repo)). Every customer copy will offer it. Type YES to continue").Trim()
        if ($yes -ne 'YES') { Write-Host 'Cancelled - nothing was published.' -ForegroundColor Yellow; return }
    }
    Write-Host "Publishing to $chosen ..." -ForegroundColor Cyan
    $user = $cfg.User; $repo = $cfg.Repo
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $cfg.Token)))
    $h = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'bluFPS-publish' }
    $api = 'https://api.github.com'

    # release notes = the newest section of CHANGELOG.txt
    $notes = ''
    $cl = Join-Path $root 'CHANGELOG.txt'
    if (Test-Path $cl) {
        $take = $false; $buf = @()
        foreach ($line in Get-Content $cl) {
            if ($line -match '^v\d') { if ($take) { break } else { $take = $true; continue } }
            if ($take) { $buf += $line }
        }
        $notes = ($buf -join "`n").Trim()
    }

    # repository (created for you if it does not exist yet)
    try { $null = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h }
    catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
            $me = "$((Invoke-RestMethod "$api/user" -Headers $h).login)"
            if ($me -ne $user) { throw "GitHub cannot find $user/$repo with this token, and the token belongs to '$me', not '$user'. Check the username and repository name." }
            Write-Host "Creating the repository $user/$repo ..."
            $body = @{ name = $repo; description = 'bluFPS releases (auto-update)'; private = $false; auto_init = $true } | ConvertTo-Json
            $null = Invoke-RestMethod "$api/user/repos" -Method Post -Headers $h -ContentType 'application/json' -Body $body
            Start-Sleep -Seconds 2
        } else { throw }
    }

    # release for this version
    $tag = "v$ver"
    $rel = $null
    try { $rel = Invoke-RestMethod "$api/repos/$user/$repo/releases/tags/$tag" -Headers $h } catch {}
    if ($rel) {
        $null = Invoke-RestMethod "$api/repos/$user/$repo/releases/$($rel.id)" -Method Patch -Headers $h -ContentType 'application/json' -Body (@{ body = $notes } | ConvertTo-Json)
    } else {
        $body = @{ tag_name = $tag; name = "bluFPS $tag"; body = $notes; draft = $false; prerelease = $false } | ConvertTo-Json
        $rel = Invoke-RestMethod "$api/repos/$user/$repo/releases" -Method Post -Headers $h -ContentType 'application/json' -Body $body
    }

    foreach ($file in @($zip, $macZip, $exe)) {
        if (-not (Test-Path $file)) { continue }
        $name = Split-Path $file -Leaf
        foreach ($a in @($rel.assets)) { if ($a.name -eq $name) { $null = Invoke-RestMethod "$api/repos/$user/$repo/releases/assets/$($a.id)" -Method Delete -Headers $h } }
        $ct = 'application/octet-stream'; if ($name -like '*.zip') { $ct = 'application/zip' }
        Write-Host "Uploading $name ..."
        $null = Invoke-RestMethod ("https://uploads.github.com/repos/$user/$repo/releases/$($rel.id)/assets?name=" + [uri]::EscapeDataString($name)) -Method Post -Headers $h -ContentType $ct -InFile $file
    }

    # keep the repository's main branch up to date too (program files, README, changelog, update.json) - one commit
    if ($cfg.PushMain -ne $false) {
        try {
            function Push-Main($api, $user, $repo, $h, $files, $message) {
                $info = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h
                $branch = "$($info.default_branch)"; if (-not $branch) { $branch = 'main' }
                $ref = $null
                try { $ref = Invoke-RestMethod "$api/repos/$user/$repo/git/ref/heads/$branch" -Headers $h } catch {}
                if (-not $ref) {
                    $first = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("# bluFPS`n"))
                    $null = Invoke-RestMethod "$api/repos/$user/$repo/contents/README.md" -Method Put -Headers $h -ContentType 'application/json' -Body (@{ message = 'Initial commit'; content = $first } | ConvertTo-Json)
                    Start-Sleep -Seconds 1
                    $info = Invoke-RestMethod "$api/repos/$user/$repo" -Headers $h; $branch = "$($info.default_branch)"
                    $ref = Invoke-RestMethod "$api/repos/$user/$repo/git/ref/heads/$branch" -Headers $h
                }
                $parent = "$($ref.object.sha)"
                $pc = Invoke-RestMethod "$api/repos/$user/$repo/git/commits/$parent" -Headers $h
                $tree = @()
                foreach ($k in @($files.Keys)) {
                    $blob = Invoke-RestMethod "$api/repos/$user/$repo/git/blobs" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ content = [Convert]::ToBase64String($files[$k]); encoding = 'base64' } | ConvertTo-Json)
                    $tree += @{ path = $k; mode = '100644'; type = 'blob'; sha = "$($blob.sha)" }
                }
                $nt = Invoke-RestMethod "$api/repos/$user/$repo/git/trees" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ base_tree = "$($pc.tree.sha)"; tree = $tree } | ConvertTo-Json -Depth 5)
                $nc = Invoke-RestMethod "$api/repos/$user/$repo/git/commits" -Method Post -Headers $h -ContentType 'application/json' -Body (@{ message = $message; tree = "$($nt.sha)"; parents = @($parent) } | ConvertTo-Json -Depth 5)
                $null = Invoke-RestMethod "$api/repos/$user/$repo/git/refs/heads/$branch" -Method Patch -Headers $h -ContentType 'application/json' -Body (@{ sha = "$($nc.sha)" } | ConvertTo-Json)
                return @{ Branch = $branch; Sha = "$($nc.sha)" }
            }
            $files = @{}
            foreach ($nm in 'bluFPS.ps1', 'bluFPS.vbs', 'bluFPS.ico', 'bluFPS.png', 'Uninstall.ps1') { $f = Join-Path $root "app\$nm"; if (Test-Path $f) { $files[$nm] = [IO.File]::ReadAllBytes($f) } }
            $clf = Join-Path $root 'CHANGELOG.txt'; if (Test-Path $clf) { $files['CHANGELOG.txt'] = [IO.File]::ReadAllBytes($clf) }
            $sha = (Get-FileHash $zip -Algorithm SHA256).Hash
            $dl = "https://github.com/$user/$repo/releases/download/$tag/" + (Split-Path $zip -Leaf)
            $files['update.json'] = [Text.Encoding]::UTF8.GetBytes((@{ version = $ver; url = $dl; sha256 = $sha; notes = $notes } | ConvertTo-Json))
            $files['README.md'] = [Text.Encoding]::UTF8.GetBytes("# bluFPS`n`nLatest version: **$ver**`n`nbluFPS updates itself: open bluFPS > Updates. Release page: https://github.com/$user/$repo/releases/tag/$tag`n`n## What is new`n`n$notes`n")
            $br = Push-Main $api $user $repo $h $files "bluFPS $tag"
            Write-Host "Main branch ($($br.Branch)) updated with version $ver (commit $($br.Sha.Substring(0, 7)))." -ForegroundColor Green
        } catch { Write-Host "The release was published, but updating the main branch failed: $($_.Exception.Message)" -ForegroundColor Yellow; if ($_.ErrorDetails -and $_.ErrorDetails.Message) { Write-Host "GitHub says: $($_.ErrorDetails.Message)" -ForegroundColor Yellow } }
    } else { Write-Host 'Main branch left alone (switched off for this destination).' }

    # the address built into new installers: always the CUSTOMERS repository once it exists
    $srcFile = Join-Path $root 'app\update-source.txt'
    if ($chosen -eq 'Customers' -or -not $all.Targets.ContainsKey('Customers')) {
        $keep = @(); if (Test-Path $srcFile) { $keep = @(Get-Content $srcFile | Where-Object { $_.Trim().StartsWith('#') }) }
        Set-Content $srcFile (@($keep) + @("$user/$repo"))
        if (Test-Path (Join-Path $root 'mac')) { Set-Content (Join-Path $root 'mac\update-source.txt') (@($keep) + @("$user/$repo")) }
        Write-Host "New installers built from now on check $user/$repo for updates."
    } else {
        Write-Host 'Testing publish: the address built into new installers was NOT changed (it stays on your Customers destination).'
    }

    Write-Host ''
    Write-Host "Published bluFPS $tag" -ForegroundColor Green
    Write-Host "https://github.com/$user/$repo/releases/tag/$tag"
    Write-Host ""
    Write-Host "Mac: bluFPS-v$ver-Mac.zip is on the release page. Macs that already have bluFPS offer it by themselves."
    Write-Host ''
    Write-Host 'Every installed bluFPS that uses the source' "$user/$repo" 'will now offer this update by itself.'
    Write-Host 'On a PC that was installed before, open bluFPS > Updates and type  ' "$user/$repo" '  as the update source (one time).'
} catch {
    Write-Host ''
    Write-Host "Publishing failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { Write-Host "GitHub says: $($_.ErrorDetails.Message)" -ForegroundColor Red }
    Write-Host 'Common causes: a PRIVATE repository (the token only has public_repo and cannot see it - make the repo public), a wrong repository name, or a token that belongs to a different account than the username you typed.' -ForegroundColor Yellow
    Write-Host 'If it says 401/403, the token is wrong or missing the public_repo permission. Delete' (Join-Path $env:APPDATA 'bluFPS\publish.json') 'to enter it again.'
}
