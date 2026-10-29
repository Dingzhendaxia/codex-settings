# 独立 Codex 技能

本目录包含 `tomd`、`archify`、`litreview` 三个技能及安装脚本。MATLAB / Simulink 工作流及其 17 个核心技能见 [matlab 配置指南](../matlab/README.md)。

## 快速使用

安装后，在 Codex 聊天中输入技能名和任务：

| 技能 | 用途 | 示例 |
| --- | --- | --- |
| `tomd` | 将文件转换为 Markdown，再阅读、提取或总结 | `使用 $tomd，读取这份 PDF，整理方法、结论和局限。` |
| `archify` | 生成可探索的架构图、流程图或独立说明页面 | `使用 $archify，把当前项目的请求处理流程画成时序图，输出 HTML。` |
| `litreview` | 从 Zotero 建立持续更新的 Obsidian 研究知识库 | `使用 $litreview，为我的课题配置 Zotero 集合和 Obsidian 目录，比较不同论文的解决方法。` |

## tomd

基于 [Microsoft MarkItDown](https://github.com/microsoft/markitdown) 先转换、检查提取质量，再阅读 Markdown。已是 Markdown 的文件直接读取；长文按章节或问题分段读取，公式、图片及复杂表格按需回看原件。

- [技能说明](tomd/SKILL.md) · [转换脚本](tomd/scripts/convert.ps1)
- 需要 PowerShell 7 和可用的 `markitdown` 命令。安装 uv 后可执行 `uv tool install "markitdown[all]" --python 3.12`。
- 常见输入包含 PDF、Office 文档、HTML 等；实际支持范围以转换器与依赖为准。默认派生文件写入任务目录的 `outputs/markitdown/`。
- 转换成功不保证公式、图像或版面完整。网络输入和外部音频处理按技能说明取得授权。

## archify

生成架构、流程、时序、数据流、状态、ERD、类图、树、时间线和瀑布图等可探索 HTML，也支持按需制作一页说明。可从需求、Mermaid 或代码仓库出发。

- [技能说明](archify/SKILL.md) · [CLI 入口](archify/bin/archify.mjs)
- 需要 Node.js；浏览器校验及其他依赖按技能说明配置，安装脚本不会自动安装。
- 通常在当前任务的 `.archify/` 中保存生成文件；实际输出路径以技能结果为准。
- 保留随附的 [LICENSE](archify/LICENSE)、[第三方声明](archify/THIRD_PARTY_NOTICES.md)和字体许可证。

## litreview

以“研究问题—方法—证据—局限”组织文献，可增量更新、继续精读、比较同一问题的不同解法，并从已读文章中发现新问题。支持换课题，不固定文章数量或问题清单。

- [技能说明](litreview/SKILL.md) · [课题配置模板](litreview/references/project-template.json) · [PDF 阅读协议](litreview/references/pdf-reading.md)
- 需要已连接、能够检索和读取论文的 Zotero MCP，以及获准访问的 Obsidian 本地目录。安装脚本只注册技能，不安装或配置 MCP。
- 首次调用提供课题名称、Zotero 集合及 Obsidian 目录；基线论文和种子问题可选。课题配置和阅读状态保存在各课题目录。
- 文献原件留在 Zotero。PDF 优先用 `tomd` 或终端 MarkItDown 转换并复用核验后的缓存，检索分段阅读，公式图表按需回看原页。
- 输出包括 `wiki/sources/` 文献来源页、`wiki/concepts/` 方法/概念页、`wiki/problems/` 问题比较页，以及索引、文献登记和阅读状态。目录可通过课题配置调整。
- 全库精读完成后归纳关键共性与研究地图；未读完时明确输出阶段归纳。支持保存进度后用“使用 `$litreview`，继续上次阅读”恢复。
- 仓库中的 [项目列表](litreview/references/projects.json) 默认为空，不包含个人路径、文献清单或库身份。选择课题时可直接指定配置文件；本地注册表如需加入私人路径，应留在本机，勿提交到仓库。
- 按调用执行，后台自动监测需要单独配置；已转换不等于已读完。

全库阅读示例：

> 使用 $litreview，对指定课题集合做全库精读，保留原笔记并保存进度；完成后归纳关键共性、不同解决路线和同方法的作者差异，不限于我提出的问题。

## 安装

先安装并登录 Codex。以下命令以 PowerShell 7 执行，仓库应放在持久目录：

```powershell
git clone https://github.com/Dingzhendaxia/codex-settings.git "$HOME\codex-settings"
pwsh -NoProfile -File "$HOME\codex-settings\skills\Install-Skills.ps1"
```

已克隆时无需再次克隆。脚本默认注册三个技能到当前用户的 `.agents/skills`，先检查完整来源，再优先创建目录联接，失败时复制。同名且内容一致的安装会跳过，其他旧安装改名备份，不自动合并个人配置。

```powershell
pwsh -NoProfile -File "$HOME\codex-settings\skills\Install-Skills.ps1" -TargetRoot "<目标技能目录的绝对路径>"
```

执行前替换占位符。脚本不安装 Node.js、MarkItDown、Zotero、Obsidian 或 MATLAB 组件，也不修改 Codex MCP 配置。重新加载技能，必要时重启 Codex。

### 禁止执行 ps1 文件时

不要降低执行策略或绕过组织限制。可在交互式 PowerShell 中执行下列等效注册命令；将来源目录改成本机仓库位置：

```powershell
$skillsSource = Join-Path $HOME 'codex-settings\skills'
$skillsTarget = Join-Path $HOME '.agents\skills'
$names = @('archify', 'tomd', 'litreview')
foreach ($name in $names) {
    if (!(Test-Path -LiteralPath (Join-Path $skillsSource "$name\SKILL.md") -PathType Leaf)) { throw "缺少技能：$name" }
}
$skillsTarget = [IO.Path]::GetFullPath($skillsTarget)
New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($name in $names) {
    $source = Join-Path $skillsSource $name
    $target = Join-Path $skillsTarget $name
    $old = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    if ($old -and $old.LinkType -in @('Junction','SymbolicLink') -and @($old.Target)[0] -eq $source) { continue }
    if ($old) {
        $backup = "$target.backup-$stamp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        foreach ($candidate in @($target,$backup)) {
            if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($candidate)) -ne $skillsTarget.TrimEnd('\','/')) { throw '备份路径越界' }
        }
        Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop
    }
    try { New-Item -ItemType Junction -Path $target -Target $source -ErrorAction Stop | Out-Null }
    catch { Copy-Item -LiteralPath $source -Destination $target -Recurse -ErrorAction Stop }
}
```

## 检查与更新

### 一条命令同步 Archify 上游、本地和 GitHub

Archify 作为上游开源技能包保留在本仓库中，本机通过目录联接或复制使用。自己的额外偏好放在包外；同步会替换整个 `skills/archify/`，保留上游许可及资源，不只替换 `SKILL.md`。

在已登录 Git、能够推送本仓库的电脑上执行：

```powershell
pwsh -NoProfile -File "$HOME\codex-settings\skills\Sync-Archify.ps1"
```

脚本从自身位置识别仓库，无需先切换目录。默认获取 `tt-a1i/archify` 的 `main`，核对包文件并执行 `doctor`，备份并同步完整技能目录，将来源 SHA 写入 `skills/archify.upstream.json`，提交并推送自己的 `origin/main`，最后只刷新本机 Archify。重复运行不产生空提交；无需另跑安装脚本，也不会重装 tomd 或 litreview。

- 需要 PowerShell 7、Git、Node.js，以及有效的 Git 提交身份和推送凭据；首次登录按 Git 提示完成。脚本不安装运行依赖。
- 仓库须在 `main` 且没有未提交文件。未推送的无关提交会导致停止；仅由上次同步留下的提交允许重试推送。不强制推送或自动处理冲突。
- 只备份和更新 Archify；更新发生时，备份路径在结果的 `Backup` 字段中。`Pushed: true` 表示已推送成功。推送失败会报错，已形成的同步提交可在凭据恢复后重跑脚本推送。
- 需要固定上游版本时使用 `-UpstreamRef <tag或commit>`；自定义安装目录使用 `-SkillsRoot <目录>`。默认本机目标为 `.agents/skills/archify`。
- Archify 自带的更新提示只负责提醒，不会替你同步本仓库。此脚本也不配置后台定时执行。

命令保留 JSON 结果（`Updated` 表示本次是否创建更新提交），并在终端显示中文摘要，区分“已更新”和“已是最新”，同时列出 GitHub 同步状态、上游版本、本地技能和备份位置。中文提示写入信息流，不影响通过管道解析 JSON。

同步脚本测试（仅推送到新建的临时本地 Git 仓库）：

```powershell
pwsh -NoProfile -File "$HOME\codex-settings\skills\tests\Sync-Archify.Tests.ps1" -TestRoot "<新的测试目录绝对路径>"
```

### 更新其他技能或获取仓库更新

检查目标目录中三个技能的 `SKILL.md` 是否可读，链接是否指向当前仓库。分别用 `$tomd`、`$archify`、`$litreview` 完成小任务，确认所需运行依赖和外部连接可用。

```powershell
git -C "$HOME\codex-settings" pull --ff-only
```

使用目录链接时会指向更新后的文件；复制安装需更新仓库后重跑脚本。移动仓库后需重新注册。旧版本备份可能包含个人配置，恢复前先核对，不要直接公开提交。

安装脚本集成检查（仅操作指定的新测试目录）：

```powershell
pwsh -NoProfile -File "$HOME\codex-settings\skills\tests\Install-Skills.Tests.ps1" -TestRoot "<新的测试目录绝对路径>"
```
