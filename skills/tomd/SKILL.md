---
name: tomd
description: Use when the user attaches or references documents, spreadsheets, slides, webpages, ebooks, archives, images, audio, or other MarkItDown-supported inputs for reading, summarizing, extracting, comparing, or Markdown conversion. 用户发送文件或要求阅读、总结、提取内容时优先使用。Does not handle file creation or editing requests by itself.
---

# tomd

用户偏好：跨项目阅读文件时，先用本机 MarkItDown 转为 Markdown，检查后再读取 Markdown 完成用户的任务。支持自动匹配，也可显式调用 `$tomd`。不要要求用户手动运行转换命令。

## 输入与格式

- 从本轮附件元数据或用户提供的路径取得真实、可访问的文件。不要把附件显示名称当成本机路径，也不要猜上传目录。如果附件工具仅返回解析文本而没有可下载文件或本机路径，应说明当前无法运行本地转换，使用可用文本或请求原文件可访问位置。
- 覆盖当前安装的 MarkItDown 能转换的所有格式，以实际转换器能力为准，不设扩展名白名单。常见输入包括 PDF、DOCX、PPTX、XLS/XLSX、HTML、CSV、JSON、XML、TXT、EPUB、Outlook 邮件、ZIP、图片、音频和 YouTube 链接。旧版 DOC/PPT、任意视频和其他格式不可仅凭名称承诺支持。
- 已经是 Markdown 的文件直接读取。对多附件逐一处理；单个失败不能阻止其他文件转换。
- 只获取用户提供、选择或完成本任务必要的资源。远程 URL 只处理明确提供的 HTTP(S) 链接，不抓取网页中的所有链接。

## 转换

Windows 使用 PowerShell 7，以当前任务工作目录作为工作目录。执行本技能旁的 `scripts/convert.ps1`，用参数数组或独立参数传路径，不拼接可执行命令字符串：

```powershell
pwsh -NoLogo -NoProfile -NonInteractive -File "<本技能目录>/scripts/convert.ps1" -Source "<输入路径>" -OutputDirectory "<当前任务目录>/outputs/markitdown"
```

明确提供的网页、YouTube 链接可作为 `-Source`，加 `-AllowNetwork`。音频转写可能向外部服务发送音频；如需要外部处理，先说明实际数据流并取得相应授权，再加 `-AllowNetwork`。视频只在当前已配置的转换服务实际支持时处理。

- 脚本通过现有 `markitdown` 命令转换，不启用额外云服务或第三方插件，输出 JSON 状态、Markdown 路径、字符数和日志路径。
- 默认输出到当前任务的 `outputs/markitdown`，不改原文件，不写入只读参考目录。沙箱限制仍然有效。
- 若命令找不到，先检查用户的 `~/.local/bin/markitdown.exe`。只有确实缺依赖时才修复独立工具环境；不向 Anaconda base 或无关项目安装。推荐工具安装命令为 `uv tool install "markitdown[all]" --python 3.12`。
- 不将“全部格式纳入流程”解释为所有文件均能成功转换。缺少解码器、密码、OCR、联网能力或 Azure/LLM 配置时，明确指出实际限制；不要静默上传文档、设置 API 密钥或启用收费服务。

## 检查并读取

1. 检查原生进程退出码和 JSON 状态。只有 `converted` 且正文非空，才算得到可读输出。`needs_network`、`empty` 或 `failed` 都需要说明或采用适合的原文件读取方式。
2. 先预览 Markdown。检查是否只有元数据、是否乱码或明显缺页。`converted` 仅表示产生文本，不保证提取完整。图片只有 EXIF、音频只有元数据时不能假装已读取内容。
3. 读取 Markdown 中与用户任务相关的全部内容；长文件按章节检索和分段读取。不要仅凭前几行就总结全文。
4. 普通文字以 Markdown 为阅读入口；公式、图像、版面关系、复杂表格或视觉问题回看原文件，并使用对应文档/图片工具。科学公式上下标和分数尤其需要核对。
5. `Could not get FontBBox ...` 是 pdfminer 字体警告。如果退出成功且文本可用，继续读取，不因此重装。保留其他错误信息以便判断。
6. 简短报告已转换和实际存在的质量限制，按用户原要求回答；用户需要时提供 Markdown 文件链接。不要要求用户再次输入“然后读取”。

技能在收到消息后指导转换，不接管应用的「＋」上传按钮，也不保证 PDF 原附件在转换前完全不会进入模型上下文。自动匹配不是每个会话都强制执行的上传钩子；需要确定调用时，使用 `$tomd`。
