<#
.SYNOPSIS
    Windows TTL Changer - view and change the default TTL (IPv4) and hop limit (IPv6).

.DESCRIPTION
    Developed by huseyinymk

    Shows the current IPv4 TTL and IPv6 hop limit values and lets you change them:

      1- Change TTL 65                    Mobile hotspot value. The phone lowers the
                                          TTL by one when it forwards a packet, so the
                                          carrier sees 64, the same value as the
                                          phone's own traffic.
      2- Change TTL Default Value (128)   The Windows default.
      3- Change TTL Custom Value          Any value from 1 to 255.

    Each change can be applied to IPv4, IPv6 or both. It takes effect immediately
    and is kept after a restart.

    Administrator rights are required. When started without them, the script
    reopens itself in an elevated window (UAC prompt).

.EXAMPLE
    Right-click Windows-TTL-Changer.ps1 and choose "Run with PowerShell".

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Windows-TTL-Changer.ps1

.NOTES
    Version: 1.0.2

    Windows TTL Changer - view and change the default TTL (IPv4) and hop limit (IPv6).
    Copyright (C) 2026  huseyinymk
    SPDX-License-Identifier: GPL-3.0-or-later

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

$ErrorActionPreference = 'Stop'

$AppVersion    = '1.0.2'
$HotspotTtl    = 65
$DefaultTtl    = 128
$ScriptFile    = $PSCommandPath
$TargetNames   = @{ IPv4 = 'IPv4'; IPv6 = 'IPv6'; Both = 'IPv4 & IPv6' }
$ProtocolNames = @{ ipv4 = 'IPv4'; ipv6 = 'IPv6' }


# --- System -----------------------------------------------------------------

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-Elevated {
    # Reopen this script in an elevated window, using the same PowerShell edition.
    $exe = (Get-Process -Id $PID).Path
    if ([IO.Path]::GetFileNameWithoutExtension($exe) -notin 'powershell', 'pwsh') {
        # Hosts such as PowerShell ISE cannot run -File, so fall back to Windows PowerShell.
        $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $ScriptFile
    Start-Process -FilePath $exe -ArgumentList $arguments -Verb RunAs
}

function Get-CurrentTtl {
    [pscustomobject]@{
        IPv4 = [int](Get-NetIPv4Protocol | Select-Object -First 1).DefaultHopLimit
        IPv6 = [int](Get-NetIPv6Protocol | Select-Object -First 1).DefaultHopLimit
    }
}

function Get-SavedHopLimit {
    # Returns the value Windows loads after a restart, or $null if it cannot be read.
    param([Parameter(Mandatory)] [ValidateSet('ipv4', 'ipv6')] [string] $Protocol)
    $ErrorActionPreference = 'Continue'
    $output = netsh interface $Protocol show global store=persistent 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    # The first "name : number" line is the default hop limit, in every display language.
    foreach ($line in $output) {
        if ("$line" -match ':\s*([0-9]+)') { return [int]$Matches[1] }
    }
    return $null
}

function Set-HopLimit {
    param(
        [Parameter(Mandatory)] [ValidateSet('ipv4', 'ipv6')] [string] $Protocol,
        [Parameter(Mandatory)] [ValidateRange(1, 255)] [int] $Value
    )
    # Windows keeps two copies of this setting: "active" is used right now and
    # "persistent" is loaded after a restart. store=persistent alone does not
    # change the active value, so write both.
    $ErrorActionPreference = 'Continue'
    foreach ($store in 'active', 'persistent') {
        $output = netsh interface $Protocol set global "defaultcurhoplimit=$Value" "store=$store" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $details = ($output | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) -join ' '
            throw "netsh could not set the $store $($ProtocolNames[$Protocol]) value. $details"
        }
    }
}

function Set-Ttl {
    param(
        [Parameter(Mandatory)] [int] $Value,
        [Parameter(Mandatory)] [ValidateSet('IPv4', 'IPv6', 'Both')] [string] $Target
    )
    $protocols = @(switch ($Target) { 'IPv4' { 'ipv4' } 'IPv6' { 'ipv6' } 'Both' { 'ipv4', 'ipv6' } })
    foreach ($protocol in $protocols) { Set-HopLimit -Protocol $protocol -Value $Value }

    # Read both copies back to make sure Windows applied them.
    $now = Get-CurrentTtl
    foreach ($protocol in $protocols) {
        $name   = $ProtocolNames[$protocol]
        $active = $now.$name
        if ($active -ne $Value) {
            throw "Windows did not apply the new $name value. It is still $active."
        }
        $saved = Get-SavedHopLimit -Protocol $protocol
        if ($null -ne $saved -and $saved -ne $Value) {
            throw "The new $name value is active, but Windows did not save it for the next restart."
        }
    }
}


# --- Menu -------------------------------------------------------------------

function Write-Header {
    $ttl = Get-CurrentTtl

    # Mention it when the value saved for the next restart differs from the current one.
    $pending = @()
    foreach ($protocol in 'ipv4', 'ipv6') {
        $name  = $ProtocolNames[$protocol]
        $saved = Get-SavedHopLimit -Protocol $protocol
        if ($null -ne $saved -and $saved -ne $ttl.$name) { $pending += "$name will be $saved" }
    }

    Clear-Host
    Write-Host ''
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host '    Windows TTL Changer' -ForegroundColor Cyan
    Write-Host '    Developed by huseyinymk' -ForegroundColor Gray
    Write-Host "    Version $AppVersion" -ForegroundColor Gray
    Write-Host '  ========================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host '    Current IPv4 TTL Value: ' -NoNewline
    Write-Host $ttl.IPv4 -ForegroundColor Yellow
    Write-Host '    Current IPv6 TTL Value: ' -NoNewline
    Write-Host $ttl.IPv6 -ForegroundColor Yellow
    if ($pending) {
        Write-Host ('    After a restart, ' + ($pending -join ' and ') + '.') -ForegroundColor DarkYellow
    }
    Write-Host ''
}

function Read-MenuChoice {
    param([string[]] $Allowed)
    while ($true) {
        $answer = Read-Host '    Select an option'
        if ($null -eq $answer) { return '0' }   # input closed: treat as Exit / Back
        $answer = $answer.Trim()
        if ($Allowed -contains $answer) { return $answer }
        Write-Host '    Invalid option, please try again.' -ForegroundColor Red
    }
}

function Read-CustomTtl {
    while ($true) {
        $answer = Read-Host '    Enter a TTL value between 1 and 255 (leave empty to cancel)'
        if ([string]::IsNullOrWhiteSpace($answer)) { return $null }
        $number = 0
        if ([int]::TryParse($answer.Trim(), [ref] $number) -and $number -ge 1 -and $number -le 255) {
            return $number
        }
        Write-Host '    Invalid value. Please enter a whole number between 1 and 255.' -ForegroundColor Red
    }
}

function Read-Target {
    Write-Host ''
    Write-Host '    Which protocol should this setting be applied to?'
    Write-Host ''
    Write-Host '    1- IPv4'
    Write-Host '    2- IPv6'
    Write-Host '    3- IPv4 & IPv6'
    Write-Host '    0- Back'
    Write-Host ''
    switch (Read-MenuChoice '1', '2', '3', '0') {
        '1' { return 'IPv4' }
        '2' { return 'IPv6' }
        '3' { return 'Both' }
    }
    return $null
}

function Show-Menu {
    $status = $null
    while ($true) {
        Write-Header
        if ($status) {
            Write-Host ('    ' + $status.Text) -ForegroundColor $status.Color
            Write-Host ''
        }
        Write-Host "    1- Change TTL $HotspotTtl"
        Write-Host "    2- Change TTL Default Value ($DefaultTtl)"
        Write-Host '    3- Change TTL Custom Value'
        Write-Host '    0- Exit'
        Write-Host ''

        $choice = Read-MenuChoice '1', '2', '3', '0'
        $status = $null

        if ($choice -eq '0') { return }
        if ($choice -eq '1') {
            $value = $HotspotTtl
        } elseif ($choice -eq '2') {
            $value = $DefaultTtl
        } else {
            Write-Host ''
            $value = Read-CustomTtl
            if ($null -eq $value) { continue }
        }

        $target = Read-Target
        if ($null -eq $target) { continue }

        try {
            Set-Ttl -Value $value -Target $target
            $status = @{ Color = 'Green'; Text = "Done. $($TargetNames[$target]) TTL set to $value." }
        } catch {
            $status = @{ Color = 'Red'; Text = "Error: $($_.Exception.Message)" }
        }
    }
}

function Start-TtlChanger {
    if (-not (Test-IsAdmin)) {
        if (-not $ScriptFile) {
            Write-Host 'Please run this script as Administrator.' -ForegroundColor Red
            return
        }
        Write-Host 'Administrator rights are required. Opening an elevated window...' -ForegroundColor Yellow
        try {
            Start-Elevated
        } catch {
            Write-Host 'Administrator permission was not granted. No changes were made.' -ForegroundColor Red
            Read-Host 'Press Enter to exit' | Out-Null
        }
        return
    }

    try { $Host.UI.RawUI.WindowTitle = 'Windows TTL Changer' } catch { }
    Show-Menu
}


# --- Entry point ------------------------------------------------------------

# Start the menu when the script is run. Dot-sourcing it only loads the functions.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Start-TtlChanger
    } catch {
        Write-Host ''
        Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host 'Press Enter to exit' | Out-Null
    }
}
