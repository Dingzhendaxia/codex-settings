# Codex 技能包

此仓库只收录本机自装的非 MATLAB 技能：`archify` 和 `tomd`。不包含 MATLAB/Simulink 工具包、MCP 配置、Codex 登录信息或密钥。

## 在另一台 Windows 电脑安装

在 PowerShell 中运行：

```powershell
git clone https://github.com/Dingzhendaxia/codex-settings.git "$HOME\codex-settings"
$skillRoot = Join-Path $HOME '.agents\skills'
New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($name in 'archify', 'tomd') {
    $source = Join-Path $HOME "codex-settings\skills\$name"
    $target = Join-Path $skillRoot $name
    if (!(Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw "缺少 $name 技能文件" }
    $old = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($old -and $old.LinkType -eq 'Junction' -and @($old.Target)[0] -eq $source) { continue }
    if ($old) { Move-Item -LiteralPath $target -Destination "$target.backup-$stamp" }
    try { New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null }
    catch { Copy-Item -LiteralPath $source -Destination $target -Recurse }
    Write-Host "已安装 $name"
}
```

这些命令直接在交互式 PowerShell 中执行，适用于禁止运行 `.ps1` 文件的执行策略。如果已有同名技能，会先改名备份。安装后重启 Codex。

## 更新

在每台电脑运行：

```powershell
git -C "$HOME\codex-settings" pull --ff-only
```

如果安装时成功建立了目录链接，拉取更新后技能会立即指向新文件。如果当时只能复制，请重新运行上面的安装命令段。不要向此仓库提交个人配置、令牌或私有文件。
