#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code / VSCode 設定を同期するセットアップスクリプト

.DESCRIPTION
    このリポジトリの設定ファイルを以下にリンク（またはコピー）します:
      - claude-config/ → C:\Users\<user>\.claude\
      - vscode/settings.json → C:\Users\<user>\AppData\Roaming\Code\User\settings.json

    新しい PC にセットアップする手順:
      1. このリポジトリを git clone（または Google Drive から利用）
      2. PowerShell を開き、このスクリプトを実行:
             powershell -ExecutionPolicy Bypass -File setup.ps1

    設定を更新した場合:
      - シンボリックリンクモードならリポジトリを更新するだけで即反映
      - コピーモードの場合は setup.ps1 を再実行
#>

$ErrorActionPreference = "Stop"

$RepoRoot      = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigSrc     = Join-Path $RepoRoot "claude-config"
$ClaudeDir     = Join-Path $env:USERPROFILE ".claude"
$VSCodeSrc     = Join-Path $RepoRoot "vscode\settings.json"
$VSCodeDst     = Join-Path $env:APPDATA "Code\User\settings.json"

Write-Host ""
Write-Host "=== Claude Code / VSCode 設定セットアップ ===" -ForegroundColor Cyan
Write-Host "リポジトリ: $RepoRoot"
Write-Host ""

# ----------------------------------------------------------------
# シンボリックリンク作成可否チェック
# ----------------------------------------------------------------
function Test-SymlinkSupport {
    $testLink   = Join-Path $env:TEMP "symtest_link_$(Get-Random)"
    $testTarget = Join-Path $env:TEMP "symtest_target_$(Get-Random)"
    try {
        New-Item -ItemType File -Path $testTarget -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
        Remove-Item $testLink   -Force -ErrorAction SilentlyContinue
        Remove-Item $testTarget -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Remove-Item $testTarget -Force -ErrorAction SilentlyContinue
        return $false
    }
}

$useSymlinks = Test-SymlinkSupport

if ($useSymlinks) {
    Write-Host "[モード] シンボリックリンク（設定変更が即反映されます）" -ForegroundColor Green
} else {
    Write-Host "[モード] コピー（設定変更後は setup.ps1 を再実行してください）" -ForegroundColor Yellow
    Write-Host "         シンボリックリンクを使うには: 開発者モードを有効にするか管理者として実行"
}
Write-Host ""

# ----------------------------------------------------------------
# ~/.claude/ への設定リンク/コピー
# ----------------------------------------------------------------
Write-Host "--- Claude Code 設定 ---"

if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    Write-Host "作成: $ClaudeDir"
}

$claudeItems = @("settings.json", "CLAUDE.md", "agents")

foreach ($item in $claudeItems) {
    $src = Join-Path $ConfigSrc $item
    $dst = Join-Path $ClaudeDir $item

    if (-not (Test-Path $src)) {
        Write-Warning "スキップ（ソースなし）: $src"
        continue
    }

    # 既存のリンク・ファイル・ディレクトリを削除
    if (Test-Path $dst) {
        Remove-Item $dst -Recurse -Force
    }

    $isDir = (Get-Item $src).PSIsContainer

    if ($useSymlinks) {
        # ディレクトリは Junction、ファイルは SymbolicLink
        $linkType = if ($isDir) { "Junction" } else { "SymbolicLink" }
        New-Item -ItemType $linkType -Path $dst -Target $src | Out-Null
        Write-Host "  リンク ($linkType): $dst" -ForegroundColor Cyan
    } else {
        if ($isDir) {
            Copy-Item -Path $src -Destination $dst -Recurse -Force
        } else {
            Copy-Item -Path $src -Destination $dst -Force
        }
        Write-Host "  コピー: $dst" -ForegroundColor Yellow
    }
}

# ----------------------------------------------------------------
# VSCode settings.json のマージ
# ----------------------------------------------------------------
Write-Host ""
Write-Host "--- VSCode 設定 ---"

$vscodeDir = Split-Path -Parent $VSCodeDst
if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
}

$newSettings = Get-Content $VSCodeSrc -Raw -Encoding UTF8 | ConvertFrom-Json

if (Test-Path $VSCodeDst) {
    # 既存設定にマージ（新設定が既存を上書き）
    try {
        $existing = Get-Content $VSCodeDst -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "既存の settings.json が不正な JSON のため上書きします"
        $existing = [PSCustomObject]@{}
    }
    $newSettings.PSObject.Properties | ForEach-Object {
        $existing | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
    }
    $existing | ConvertTo-Json -Depth 10 | Set-Content $VSCodeDst -Encoding UTF8
    Write-Host "  マージ完了: $VSCodeDst" -ForegroundColor Cyan
} else {
    $newSettings | ConvertTo-Json -Depth 10 | Set-Content $VSCodeDst -Encoding UTF8
    Write-Host "  作成完了: $VSCodeDst" -ForegroundColor Cyan
}

# ----------------------------------------------------------------
# 完了
# ----------------------------------------------------------------
Write-Host ""
Write-Host "=== セットアップ完了 ===" -ForegroundColor Green
Write-Host ""
Write-Host "次回以降の更新手順:"
Write-Host "  git pull  # リポジトリを最新化"
if (-not $useSymlinks) {
    Write-Host "  powershell -ExecutionPolicy Bypass -File setup.ps1  # 設定を再適用"
}
Write-Host ""
