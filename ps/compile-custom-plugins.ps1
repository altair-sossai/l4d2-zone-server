#Requires -Version 5.1
<#
.SYNOPSIS
    Compiles the custom SourceMod plugins using the compiler committed in the repo.
.PARAMETER Plugin
    One or more plugin names to compile (with or without the .sp extension).
    If omitted, every plugin in the build list is compiled.
.EXAMPLE
    .\compile-custom-plugins.ps1
    Compiles all plugins.
.EXAMPLE
    .\compile-custom-plugins.ps1 l4d2_queue
    Compiles only l4d2_queue.
.EXAMPLE
    .\compile-custom-plugins.ps1 l4d2_queue l4d2_mix
    Compiles only l4d2_queue and l4d2_mix.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Plugin
)
$ErrorActionPreference = "Stop"

# Paths resolved from the repo, so the build never depends on what is
# installed on the machine (C:\Program Files\SourceMod, PATH, etc.).
$repo      = Split-Path $PSScriptRoot -Parent
$scripting = Join-Path $repo "addons\sourcemod\scripting"
$plugins   = Join-Path $repo "addons\sourcemod\plugins"

# Pinned compiler committed in the repo (SourceMod 1.12.0.7230),
# matching the includes and the SourceMod running on the server.
$spcomp    = Join-Path $scripting "sourcemod\spcomp.exe"

# Include search paths: custom includes first, then the standard SM ones.
$incCustom = Join-Path $scripting "include"
$incStd    = Join-Path $scripting "sourcemod\include"

if (-not (Test-Path $spcomp)) { throw "Compiler not found: $spcomp" }

# src (relative to scripting\)  ->  out (relative to plugins\)
$targets = @(
    @{ src = "l4d2_alltalk_before_round_start.sp"; out = "optional\l4d2_alltalk_before_round_start.smx" },
    @{ src = "l4d2_queue.sp";                       out = "optional\l4d2_queue.smx" },
    @{ src = "l4d2_friendly_fire_control.sp";       out = "optional\l4d2_friendly_fire_control.smx" },
    @{ src = "l4d2_mix.sp";                         out = "optional\l4d2_mix.smx" },
    @{ src = "l4d2_spectating_cheat.sp";            out = "optional\l4d2_spectating_cheat.smx" },
    @{ src = "l4d2_connect_announce.sp";            out = "optional\l4d2_connect_announce.smx" },
    @{ src = "l4d2_tank_is_comming.sp";             out = "optional\l4d2_tank_is_comming.smx" },
    @{ src = "l4d_death_item_glow.sp";              out = "optional\l4d_death_item_glow.smx" },
    @{ src = "l4d2_playstats_sync.sp";              out = "optional\l4d2_playstats_sync.smx" },
    @{ src = "l4d2_ranking.sp";                     out = "optional\l4d2_ranking.smx" },
    @{ src = "l4d2_show_patent_icon.sp";            out = "optional\l4d2_show_patent_icon.smx" },
    @{ src = "l4d2_no_skip_getup_animation.sp";     out = "optional\l4d2_no_skip_getup_animation.smx" },
    @{ src = "l4d2_jockey_no_deadstops.sp";         out = "optional\l4d2_jockey_no_deadstops.smx" },
    @{ src = "l4d2_gameinfo_sync.sp";               out = "l4d2_gameinfo_sync.smx" },
    @{ src = "l4d2_admin_hp.sp";                    out = "optional\l4d2_admin_hp.smx" },
    @{ src = "l4d2_admin_spec_lock.sp";             out = "optional\l4d2_admin_spec_lock.smx" },
    @{ src = "map-decals.sp";                       out = "optional\map-decals.smx" },
    @{ src = "l4d2_early_victory.sp";               out = "optional\l4d2_early_victory.smx" },
    @{ src = "l4d2_afk_to_spec.sp";                 out = "optional\l4d2_afk_to_spec.smx" },
    @{ src = "l4d2_spec_lister.sp";                 out = "optional\l4d2_spec_lister.smx" },
    @{ src = "l4d2_block_spec_during_tank.sp";      out = "optional\l4d2_block_spec_during_tank.smx" },
    @{ src = "l4d2_custom_commands.sp";             out = "optional\l4d2_custom_commands.smx" },
    @{ src = "l4d2_campaign_vote.sp";               out = "optional\l4d2_campaign_vote.smx" }
)

# If plugin names were passed, compile only those. Match on the file name
# without the .sp extension (case-insensitive).
if ($Plugin) {
    $selected = @()
    foreach ($name in $Plugin) {
        $key   = ($name -replace '\.sp$', '').Trim()
        $match = $targets | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.src) -ieq $key }
        if (-not $match) {
            $available = ($targets | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.src) }) -join ", "
            throw "Plugin '$key' is not in the build list.`nAvailable: $available"
        }
        $selected += $match
    }
    $targets = $selected
}

$failed = 0
foreach ($t in $targets) {
    $src = Join-Path $scripting $t.src
    $out = Join-Path $plugins   $t.out

    Write-Host "Compiling $($t.src) -> $($t.out)" -ForegroundColor Cyan
    & $spcomp $src "-i=$incCustom" "-i=$incStd" -o $out
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED: $($t.src)" -ForegroundColor Red
        $failed++
    }
}

if ($failed -gt 0) { throw "$failed plugin(s) failed to compile." }
Write-Host "All $($targets.Count) plugins compiled successfully." -ForegroundColor Green
