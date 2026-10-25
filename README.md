# Codex 技能包

此仓库只收录本机自装的非 MATLAB 技能：`archify` 和 `tomd`。不包含 MATLAB/Simulink 工具包、MCP 配置、Codex 登录信息或密钥。

## 在另一台 Windows 电脑安装

在 PowerShell 7 中运行：

```powershell
git clone https://github.com/Dingzhendaxia/codex-settings.git "$HOME\codex-settings"
& "$HOME\codex-settings\Install-Skills.ps1"
```

脚本会把两个技能连接到 `$HOME\.agents\skills`。如果那里已经有同名技能，会先改名备份。安装后重启 Codex。

## 更新

在每台电脑运行：

```powershell
git -C "$HOME\codex-settings" pull --ff-only
& "$HOME\codex-settings\Install-Skills.ps1"
```

如果本机不支持创建目录链接，脚本会复制技能文件。此时每次拉取更新后都要重新运行安装脚本。不要向此仓库提交个人配置、令牌或私有文件。
