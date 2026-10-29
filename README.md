# Codex 配置与技能

用于配置和扩展 Codex 的工作环境，收录文件阅读、可视化、文献研究和 MATLAB / Simulink 工作流四个模块。配置说明使用通用路径或环境变量，方便在不同 Windows 电脑上复用。

## 模块导航

| 模块 | 用途 | 入口 |
| --- | --- | --- |
| tomd | 基于 Microsoft MarkItDown，将文档等输入转换为 Markdown，供 Codex 阅读、提取和总结 | [技能安装与使用](skills/README.md#tomd) |
| archify | 开源可视化技能，生成可探索的 HTML 图表和说明页面 | [技能安装与使用](skills/README.md#archify) |
| litreview | 从 Zotero 增量整理文献到 Obsidian，比较方法、发现研究问题并保存阅读进度 | [技能安装与使用](skills/README.md#litreview) |
| MATLAB / Simulink | 连接 Codex 与本机 MATLAB，配置三个 MathWorks 组件、核心技能和自动初始化 | [工作流配置指南](matlab/README.md) |

仓库包含三个独立技能目录，以及一个配套工作流模块。MATLAB 工作流所需的官方组件和技能通过官方安装器获取。

## 目录结构

```text
codex-settings/
├── README.md                         # 项目总览
├── .gitignore
├── skills/                           # 独立技能及其安装入口
│   ├── README.md
│   ├── Install-Skills.ps1
│   ├── tomd/
│   ├── archify/
│   └── litreview/
└── matlab/                           # MATLAB / Simulink 工作流
    ├── README.md
    ├── 配置提示词.md
    ├── config.matlab.example.toml
    ├── startup.m
    └── finish_agentic_install.m
```

## 从哪里开始

- 安装文件阅读、可视化或文献研究技能：阅读 [skills/README.md](skills/README.md)，执行该目录中的安装脚本。
- 在新电脑配置 MATLAB 工作流：将 [matlab/配置提示词.md](matlab/配置提示词.md) 中的提示词交给目标电脑上的 Codex，再按[配置指南中的分层验收](matlab/README.md#7-分层验收)验证。

两个子项目可独立使用。`skills` 安装脚本只注册 tomd、archify 和 litreview；MATLAB 的三个组件及 17 个核心技能按 `matlab` 指南单独配置。

## 更新与来源

在本地仓库目录运行 `git pull --ff-only` 获取更新。各模块的依赖、安装方式、更新注意事项和来源链接见对应子目录说明。

archify 保留其随附的许可证和第三方声明；tomd 基于 [Microsoft MarkItDown](https://github.com/microsoft/markitdown)；litreview 提供通用文献研究流程，课题配置与私人阅读状态留在本机；MATLAB 组件来自 MathWorks 官方仓库。本仓库不包含 MATLAB 本体、官方工具包二进制、实际用户配置、登录信息或密钥。
