[CmdletBinding()]
param(
    [Alias("self-test")]
    [switch]$SelfTest,
    [Alias("h")]
    [switch]$Help
)

$script:Version = "0.2.0"
$script:AppName = "Peak Utility"
$script:DefaultRoot = "C:\Users\Andrew\Downloads\Insstincts Optimizations-main-20260411T030202Z-3-001\Insstincts Optimizations-main"
$script:LogFile = Join-Path $PSScriptRoot "PeakUtility.log"
$script:AuthFile = Join-Path $PSScriptRoot "PeakUtility.auth.json"
$script:AuthIterations = 120000
$script:Categories = @(
    @{ Key = "1"; Folder = "1 Check"; Title = "Check / Diagnostics" }
    @{ Key = "2"; Folder = "2 Refresh"; Title = "Refresh" }
    @{ Key = "3"; Folder = "3 Setup"; Title = "Setup" }
    @{ Key = "4"; Folder = "4 Installers"; Title = "Installers" }
    @{ Key = "5"; Folder = "5 Graphics"; Title = "Graphics" }
    @{ Key = "6"; Folder = "6 Windows"; Title = "Windows" }
    @{ Key = "7"; Folder = "7 Hardware"; Title = "Hardware" }
    @{ Key = "8"; Folder = "8 Advanced"; Title = "Advanced" }
)

function Show-Help {
    Write-Host "$script:AppName $script:Version"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  PeakUtility.bat"
    Write-Host "  PeakUtility.ps1"
    Write-Host "  PeakUtility.ps1 -SelfTest"
    Write-Host ""
    Write-Host "Double-click PeakUtility.bat for the easiest launch."
}

function ConvertFrom-SecurePassword {
    param([Parameter(Mandatory)][Security.SecureString]$SecurePassword)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function New-RandomSalt {
    $salt = New-Object byte[] 16
    $rng = [Security.Cryptography.RNGCryptoServiceProvider]::Create()
    try {
        $rng.GetBytes($salt)
    }
    finally {
        $rng.Dispose()
    }

    return $salt
}

function Get-PasswordHash {
    param(
        [Parameter(Mandatory)][string]$Password,
        [Parameter(Mandatory)][byte[]]$Salt,
        [Parameter(Mandatory)][int]$Iterations
    )

    $derive = New-Object Security.Cryptography.Rfc2898DeriveBytes -ArgumentList $Password, $Salt, $Iterations
    try {
        return [Convert]::ToBase64String($derive.GetBytes(32))
    }
    finally {
        $derive.Dispose()
    }
}

function Test-HashMatch {
    param(
        [Parameter(Mandatory)][string]$ExpectedHash,
        [Parameter(Mandatory)][string]$ActualHash
    )

    $expectedBytes = [Convert]::FromBase64String($ExpectedHash)
    $actualBytes = [Convert]::FromBase64String($ActualHash)

    if ($expectedBytes.Length -ne $actualBytes.Length) {
        return $false
    }

    $diff = 0
    for ($index = 0; $index -lt $expectedBytes.Length; $index++) {
        $diff = $diff -bor ($expectedBytes[$index] -bxor $actualBytes[$index])
    }

    return $diff -eq 0
}

function Read-AuthConfig {
    if (-not (Test-Path -LiteralPath $script:AuthFile -PathType Leaf)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $script:AuthFile -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function New-AuthConfig {
    while ($true) {
        Show-Header
        Write-Host "Create Peak Utility sign-in"
        Write-Host ""

        $username = (Read-Host "Username").Trim()
        if ([string]::IsNullOrWhiteSpace($username)) {
            Write-Host ""
            Write-Host "Username cannot be blank."
            Start-Sleep -Seconds 1
            continue
        }

        $password = ConvertFrom-SecurePassword (Read-Host "Password" -AsSecureString)
        $confirmPassword = ConvertFrom-SecurePassword (Read-Host "Confirm password" -AsSecureString)

        if ([string]::IsNullOrEmpty($password)) {
            Write-Host ""
            Write-Host "Password cannot be blank."
            Start-Sleep -Seconds 1
            continue
        }

        if ($password -cne $confirmPassword) {
            Write-Host ""
            Write-Host "Passwords did not match."
            Start-Sleep -Seconds 1
            continue
        }

        $salt = New-RandomSalt
        $config = [pscustomobject]@{
            username = $username
            salt = [Convert]::ToBase64String($salt)
            hash = Get-PasswordHash -Password $password -Salt $salt -Iterations $script:AuthIterations
            iterations = $script:AuthIterations
            createdUtc = (Get-Date).ToUniversalTime().ToString("o")
        }

        $config | ConvertTo-Json | Set-Content -LiteralPath $script:AuthFile -Encoding UTF8
        Write-Host ""
        Write-Host "Sign-in created."
        Start-Sleep -Seconds 1
        return $config
    }
}

function Invoke-UserAuth {
    $auth = Read-AuthConfig
    if ($null -eq $auth) {
        $auth = New-AuthConfig
    }

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Show-Header
        Write-Host "Sign in"
        Write-Host ""

        $username = (Read-Host "Username").Trim()
        $password = ConvertFrom-SecurePassword (Read-Host "Password" -AsSecureString)

        try {
            $salt = [Convert]::FromBase64String($auth.salt)
            $actualHash = Get-PasswordHash -Password $password -Salt $salt -Iterations ([int]$auth.iterations)
            $userMatches = [string]::Equals($username, [string]$auth.username, [StringComparison]::OrdinalIgnoreCase)

            if ($userMatches -and (Test-HashMatch -ExpectedHash ([string]$auth.hash) -ActualHash $actualHash)) {
                return
            }
        }
        catch {
            Write-Host ""
            Write-Host "The auth file is invalid. Creating a fresh sign-in."
            Start-Sleep -Seconds 1
            New-AuthConfig | Out-Null
            return
        }

        Write-Host ""
        Write-Host "Invalid username or password."
        Start-Sleep -Seconds 1
    }

    Write-Host ""
    Write-Host "Too many failed sign-in attempts."
    exit 1
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdmin {
    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy"
        "Bypass"
        "-File"
        "`"$PSCommandPath`""
    )

    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WorkingDirectory $PSScriptRoot -Verb RunAs
    exit
}

function Show-Header {
    Clear-Host
    Write-Host "============================================================"
    Write-Host " $script:AppName $script:Version"
    Write-Host "============================================================"
    Write-Host ""
}

function Resolve-OptimizationRoot {
    $localRoot = $PSScriptRoot

    if (Test-Path -LiteralPath (Join-Path $localRoot "1 Check") -PathType Container) {
        return $localRoot
    }

    if (Test-Path -LiteralPath (Join-Path $script:DefaultRoot "1 Check") -PathType Container) {
        return $script:DefaultRoot
    }

    while ($true) {
        Show-Header
        Write-Host "I could not find the Insstincts folders automatically."
        Write-Host "Paste the path that contains `"1 Check`", `"2 Refresh`", and the other sections."
        Write-Host ""

        $path = (Read-Host "Folder path").Trim('"').Trim()
        if (Test-Path -LiteralPath (Join-Path $path "1 Check") -PathType Container) {
            return $path
        }

        Write-Host ""
        Write-Host "That path does not look like the Insstincts optimization root."
        Pause
    }
}

function Write-Log {
    param([Parameter(Mandatory)][string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -LiteralPath $script:LogFile -Value $line
}

function Initialize-Log {
    Write-Log ""
    Write-Log "$script:AppName $script:Version started"
    Write-Log "Root: $script:OptRoot"
}

function New-PeakRestorePoint {
    Write-Host ""
    Write-Host "Creating restore point..."
    Write-Log "CREATE RESTORE POINT"

    try {
        Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Peak Utility" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "Restore point created."
        Write-Log "RESTORE POINT CREATED"
    }
    catch {
        Write-Host ""
        Write-Host "Restore point could not be created. You can still continue, but be careful."
        Write-Host $_.Exception.Message
        Write-Log "RESTORE POINT FAILED: $($_.Exception.Message)"
    }

    Pause
}

function Ask-RestorePoint {
    Show-Header
    Write-Host "Recommended before applying system tweaks:"
    Write-Host "Create a Windows restore point now?"
    Write-Host ""

    do {
        $choice = (Read-Host "[Y] Yes  [N] No").Trim()
    } until ($choice -match "^[YyNn]$")

    if ($choice -match "^[Yy]$") {
        New-PeakRestorePoint
    }
}

function Get-CategoryItems {
    param([Parameter(Mandatory)][string]$CategoryPath)

    if (-not (Test-Path -LiteralPath $CategoryPath -PathType Container)) {
        return @()
    }

    Get-ChildItem -LiteralPath $CategoryPath -File |
        Where-Object { $_.BaseName -match "^(\d+)\s+(.+)$" } |
        Sort-Object @{ Expression = { [int]([regex]::Match($_.BaseName, "^(\d+)").Groups[1].Value) } }, Name |
        ForEach-Object {
            $match = [regex]::Match($_.BaseName, "^(\d+)\s+(.+)$")
            [pscustomobject]@{
                Number = [int]$match.Groups[1].Value
                Display = "{0} {1}" -f $match.Groups[2].Value, $_.Extension
                Path = $_.FullName
                Extension = $_.Extension.ToLowerInvariant()
                Name = $_.Name
            }
        }
}

function Invoke-PeakItem {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$NoPause
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Host ""
        Write-Host "File not found:"
        Write-Host $Path
        Pause
        return 1
    }

    $item = Get-Item -LiteralPath $Path
    $runCode = 0

    Show-Header
    Write-Host "Running: $($item.Name)"
    Write-Host "Path: $($item.FullName)"
    Write-Host ""
    Write-Log "START $($item.FullName)"

    try {
        Push-Location $item.DirectoryName

        switch ($item.Extension.ToLowerInvariant()) {
            ".ps1" {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $item.FullName
                $runCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            ".cmd" {
                & cmd.exe /c "`"$($item.FullName)`""
                $runCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            ".bat" {
                & cmd.exe /c "`"$($item.FullName)`""
                $runCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            }
            ".url" {
                Start-Process -FilePath $item.FullName
                $runCode = 0
            }
            ".lnk" {
                Start-Process -FilePath $item.FullName
                $runCode = 0
            }
            default {
                Start-Process -FilePath $item.FullName
                $runCode = 0
            }
        }
    }
    catch {
        $runCode = 1
        Write-Host ""
        Write-Host $_.Exception.Message
        Write-Log "ERROR $($item.FullName): $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }

    Write-Log "END $($item.FullName) (exit $runCode)"
    Write-Host ""
    Write-Host "Done. Exit code: $runCode"

    if (-not $NoPause) {
        Pause
    }

    return $runCode
}

function Show-CategoryMenu {
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$Title
    )

    $categoryPath = Join-Path $script:OptRoot $Folder

    if (-not (Test-Path -LiteralPath $categoryPath -PathType Container)) {
        Write-Host ""
        Write-Host "Missing category folder:"
        Write-Host $categoryPath
        Pause
        return
    }

    while ($true) {
        Show-Header
        Write-Host $Title
        Write-Host ""

        $items = @(Get-CategoryItems -CategoryPath $categoryPath)
        for ($index = 0; $index -lt $items.Count; $index++) {
            Write-Host ("[{0}] {1}" -f ($index + 1), $items[$index].Display)
        }

        if ($items.Count -eq 0) {
            Write-Host "No runnable items found in this section."
            Write-Host ""
        }

        Write-Host ""
        Write-Host "[A] Run every item in this section"
        Write-Host "[B] Back"
        Write-Host "[Q] Quit"
        Write-Host ""

        $choice = (Read-Host "Select").Trim()

        if ($choice -match "^[Bb]$") { return }
        if ($choice -match "^[Qq]$") { exit }

        if ($choice -match "^[Aa]$") {
            Write-Host ""
            Write-Host "This will run every item in `"$Title`" one at a time."
            Write-Host "Some items may open browser pages, Windows settings, installers, or scripts."
            $confirm = (Read-Host "Continue? [Y/N]").Trim()

            if ($confirm -match "^[Yy]$") {
                foreach ($item in $items) {
                    Invoke-PeakItem -Path $item.Path -NoPause | Out-Null
                }

                Write-Host ""
                Write-Host "Finished section: $Title"
                Pause
            }

            continue
        }

        if ($choice -match "^\d+$") {
            $selectedIndex = [int]$choice - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $items.Count) {
                Invoke-PeakItem -Path $items[$selectedIndex].Path | Out-Null
                continue
            }
        }

        Write-Host ""
        Write-Host "Invalid choice."
        Start-Sleep -Seconds 1
    }
}

function Show-MainMenu {
    while ($true) {
        Show-Header
        foreach ($category in $script:Categories) {
            Write-Host ("[{0}] {1}" -f $category.Key, $category.Title)
        }

        Write-Host ""
        Write-Host "[A] Allow Scripts helper"
        Write-Host "[R] Create restore point"
        Write-Host "[O] Open Insstincts folder"
        Write-Host "[Q] Quit"
        Write-Host ""

        $choice = (Read-Host "Select").Trim()

        if ($choice -match "^[Qq]$") { return }

        if ($choice -match "^[Aa]$") {
            Invoke-PeakItem -Path (Join-Path $script:OptRoot "Allow Scripts.cmd") | Out-Null
            continue
        }

        if ($choice -match "^[Rr]$") {
            New-PeakRestorePoint
            continue
        }

        if ($choice -match "^[Oo]$") {
            Start-Process -FilePath $script:OptRoot
            continue
        }

        $category = $script:Categories | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
        if ($category) {
            Show-CategoryMenu -Folder $category.Folder -Title $category.Title
            continue
        }

        Write-Host ""
        Write-Host "Invalid choice."
        Start-Sleep -Seconds 1
    }
}

function Invoke-SelfTest {
    $script:OptRoot = Resolve-OptimizationRoot
    Write-Host "Root: $script:OptRoot"
    Write-Host ""

    $totalItems = 0
    foreach ($category in $script:Categories) {
        $items = @(Get-CategoryItems -CategoryPath (Join-Path $script:OptRoot $category.Folder))
        $totalItems += $items.Count
        Write-Host ("{0}: {1} items" -f $category.Folder, $items.Count)
    }

    Write-Host ""
    Write-Host "Total menu items: $totalItems"
}

if ($Help) {
    Show-Help
    exit 0
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

if (-not (Test-IsAdmin)) {
    Restart-AsAdmin
}

$Host.UI.RawUI.WindowTitle = "$script:AppName $script:Version"
Invoke-UserAuth
$script:OptRoot = Resolve-OptimizationRoot
Initialize-Log
Ask-RestorePoint
Show-MainMenu

Write-Host ""
Write-Host "Exiting $script:AppName."
