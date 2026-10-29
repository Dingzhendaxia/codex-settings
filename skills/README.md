# 独立 Codex 技能

本目录包含 `tomd` 和 `archify` 两个技能，以及仅用于注册这两个技能的安装脚本。MATLAB / Simulink 工作流及其 17 个核心技能见 [matlab 配置指南](../matlab/README.md)。

## tomd

基于 [Microsoft MarkItDown](https://github.com/microsoft/markitdown) 的文件阅读技能：先将输入转换为 Markdown，检查提取质量，再交给 Codex 阅读、提取、比较或总结。也可显式调用 `$tomd`。

- [技能说明](tomd/SKILL.md)
- [转换脚本](tomd/scripts/convert.ps1)
- 需要 PowerShell 7 和可用的 `markitdown` 命令。技能注册本身不会安装转换依赖。
- 可在安装 uv 后使用 `uv tool install "markitdown[all]" --python 3.12` 建立独立工具环境。
- 常见输入包括 Office 文档、PDF、HTML 等，实际支持范围以安装的转换器及依赖为准。转换成功不保证公式、图片或版面信息完整；需要时回看原文件。
- 网络输入或外部音频处理遵循技能中的授权要求。

## archify

开源可视化技能，用于生成架构、流程、时序、数据流、状态、ERD、类图、树、时间线和瀑布图等可探索的 HTML，以及按需生成说明页面。

- [技能说明](archify/SKILL.md)
- [CLI 入口](archify/bin/archify.mjs)：通过 Node.js 运行。
- 使用前需要可用的 Node.js；浏览器校验和其他运行依赖按技能说明处理，安装脚本不会自动安装。
- 保留随附的 [LICENSE](archify/LICENSE)、[第三方声明](archify/THIRD_PARTY_NOTICES.md)和字体许可证。

## 安装

先安装并登录 Codex。以下命令以 PowerShell 7 执行；仓库可放在任意持久目录。下面使用用户目录作为通用示例：

```powershell
git clone https://github.com/Dingzhendaxia/codex-settings.git "$HOME\codex-settings"
pwsh -NoProfile -File "$HOME\codex-settings\skills\Install-Skills.ps1"
```

已克隆仓库时无需再次克隆。安装后重新加载 Codex 技能，必要时重启 Codex。

脚本默认将技能注册到当前用户的 `.agents/skills`。优先创建指向仓库的目录联接，失败时复制；同名旧技能会先检查，必要时改名备份。也可指定目标目录：

```powershell
pwsh -NoProfile -File "$HOME\codex-settings\skills\Install-Skills.ps1" -TargetRoot "<目标技能目录的绝对路径>"
```

`<目标技能目录的绝对路径>` 是占位符，执行前替换。安装脚本不安装 MATLAB 组件，也不修改 Codex MCP 配置。

### 禁止执行 ps1 文件时

可在交互式 PowerShell 中执行下面的等效注册命令。将 `$skillsSource` 设为本机仓库的 `skills` 目录；不要降低执行策略或绕过组织限制。

```powershell
$skillsSource = Join-Path $HOME 'codex-settings\skills'
$skillsTarget = Join-Path $HOME '.agents\skills'
New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($name in @('archify', 'tomd')) {
    $source = Join-Path $skillsSource $name
    $target = Join-Path $skillsTarget $name
    if (!(Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) { throw "缺少技能：$name" }
    $old = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($old -and $old.LinkType -eq 'Junction' -and @($old.Target)[0] -eq $source) { continue }
    if ($old) { Move-Item -LiteralPath $target -Destination "$target.backup-$stamp" -ErrorAction Stop }
    try { New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null }
    catch { Copy-Item -LiteralPath $source -Destination $target -Recurse -ErrorAction Stop }
}
```

## 检查与更新

安装后检查目标目录下两个技能的 `SKILL.md` 是否可读，目录链接是否指向当前仓库。可让 Codex 显式使用 `$tomd` 或 `$archify` 完成一个小任务，进一步确认运行依赖可用。

```powershell
git -C "$HOME\codex-settings" pull --ff-only
```

使用目录链接时，技能会指向更新后的仓库文件；使用复制方式时，更新仓库后需重新运行安装脚本。保持仓库所在目录可用，移动仓库后需重新注册技能链接。
