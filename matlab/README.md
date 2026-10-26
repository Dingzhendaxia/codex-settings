# MATLAB / Simulink 与 Codex（Windows）

目标：正常打开 MATLAB 后，由 startup 自动初始化 Simulink Agentic Toolkit 并共享会话；Codex 通过 MATLAB MCP Server 连接该会话。

本目录是独立新增模块，不改变仓库原有 archify、tomd 安装流程。仅保存说明和模板；官方组件从 MathWorks 官方仓库下载。

## 版本与前提

Windows x64；已安装 MATLAB R2023a 或更新版本及有效 Simulink 许可。MATLAB / Simulink 本体不由这里安装。

| 组件 | 本次验证版本 |
| --- | --- |
| Agentic Toolkit Installer | v0.2.0 |
| MATLAB Agentic Toolkit | MATK-2026.10.b |
| MATLAB MCP Server | v0.15.0 |
| Simulink Agentic Toolkit | SATK-2026.10.c |

本次在 R2026b 验证。迁移到其他版本时，先核对官方兼容性和资产可用性，不要静默替换版本。

## 1. 检测与备份

优先在正常打开的 MATLAB 中执行（全部带分号，粘贴成单行也能运行）：

```matlab
disp(matlabroot); disp(userpath); which('startup','-all'); disp(ver('simulink'));
```

PowerShell 可用 Get-Command matlab、开始菜单快捷方式、已安装程序信息辅助定位。MATLAB 根目录包含 bin 和 toolbox，传给安装器时不要加末尾 bin。

检查实际 Codex 配置：若设置 CODEX_HOME，使用其 config.toml；否则为用户目录 .codex/config.toml。检查 .agents/skills、现有工具包和实际生效 startup。准备修改的现有文件必须先备份；保留其他 MCP、技能和启动代码。

## 2. 下载与安装

从[官方固定版本资产](https://github.com/matlab/agentic-toolkit-installer/releases/download/v0.2.0/agentic-toolkit-installer-windows-x64.exe)下载，保存为持久目录中的 agentic-toolkit-installer.exe。先运行 --help / install --help，确认来源和参数。

下面变量必须赋为本机实际绝对路径：

```powershell
$installer = 'C:\path\to\agentic-toolkit-installer.exe'
$matlabRoot = 'D:\path\to\MATLAB'
& $installer install --non-interactive --matlab-root $matlabRoot --version 'matlab-agentic-toolkit=MATK-2026.10.b' --version 'matlab-mcp-server=v0.15.0' --version 'simulink-agentic-toolkit=SATK-2026.10.c' --skip-configure --disable-telemetry
& $installer status
```

--skip-configure 避免自动改动其他代理配置。默认安装根为 %APPDATA%\MathWorks\Agentic Toolkits\v1。若无权写入，可显式追加 --app-data 指定另一个持久目录；本次传入 C:\Users\wl\Documents\Codex\MathWorks-Agentic-Toolkits，实际根目录追加了 v1。后续 status 也传相同 --app-data。

必须确认 bin/matlab-mcp-server.exe、两个 mltbx 和 toolkits 下的工具包文件存在。安装器即使返回0，也可能提示 Failed to install toolkits，必须查看输出和日志。

HTTPS 下载遇到 Windows schannel/身份凭据错误时，可用已有 Node.js fetch 下载同一官方地址。不要关闭证书校验或改用未知镜像。权限不足时走环境的权限申请机制。

## 3. MATLAB 附加组件与初始化

若安装器附加组件注册失败，而用户正常 MATLAB 可用，不要据此认定许可证损坏。编辑 [finish_agentic_install.m](finish_agentic_install.m) 的 agenticRoot 为实际根目录，在已打开的 MATLAB 运行：

```matlab
run('C:/path/to/codex-settings/matlab/finish_agentic_install.m');
```

该脚本安装两个附加组件并初始化 SATK。预期 Installation Check 为 PASS，connector 正在运行。保持 MATLAB 打开。若插件已装好，可直接初始化，无需每次重装。

## 4. MCP 配置

将 [config.matlab.example.toml](config.matlab.example.toml) 中的绝对路径替换为实际路径，仅添加或合并 matlab 服务段，不能覆盖整份用户配置或产生重复段。

- existing 模式连接已打开且共享的 MATLAB。
- 不同时指定 --matlab-root、--initial-working-folder、--matlab-display-mode。
- Windows 转发 WINDIR。
- 最终 TOML 不能残留占位符、%APPDATA% 或 PowerShell 变量。

```powershell
codex mcp get matlab
```

成功解析配置不代表实际调用成功。手动配置后，安装器 status 可能不显示 Codex 注册状态；以实际调用为准。

## 5. 注册17个核心技能

仅启用 matlab-core（6个）和 model-based-design-core（11个）。在交互式 PowerShell 中运行，先调整根目录：

```powershell
$agenticRoot = Join-Path $env:APPDATA 'MathWorks\Agentic Toolkits\v1'
$skillsRoot = Join-Path $env:USERPROFILE '.agents\skills'
$groups = @(
    (Join-Path $agenticRoot 'toolkits\matlab-agentic-toolkit\skills-catalog\matlab-core'),
    (Join-Path $agenticRoot 'toolkits\simulink-agentic-toolkit\skills-catalog\model-based-design-core')
)
New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
foreach ($group in $groups) {
    foreach ($entry in (Get-ChildItem -LiteralPath $group -Directory -Force)) {
        if (!(Test-Path -LiteralPath (Join-Path $entry.FullName 'SKILL.md'))) { continue }
        $destination = Join-Path $skillsRoot $entry.Name
        $old = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        if ($old) {
            if ($old.LinkType -eq 'Junction' -and @($old.Target)[0] -eq $entry.FullName) { continue }
            Write-Warning "保留已有技能，请先检查并备份：$destination"
            continue
        }
        try { New-Item -ItemType Junction -Path $destination -Target $entry.FullName -ErrorAction Stop | Out-Null }
        catch { Copy-Item -LiteralPath $entry.FullName -Destination $destination -Recurse -ErrorAction Stop }
    }
}
```

自定义安装时必须改 agenticRoot。链接指向持久工具包目录，不能指向临时下载缓存。复制回退时，日后更新需同步复制。数量应为这两个组共17个，用户技能目录总数可以更大；遇到冲突要核对，不能声称所有技能已注册。

## 6. startup 自动初始化

先以 which('startup','-all') 确定实际生效文件。

- 没有已有 startup：将 [startup.m](startup.m) 放入已确认的 userpath。
- 自定义安装：修改脚本 toolkitRoot 为实际根目录。
- 已有 startup：先备份，将调用放进脚本执行区，将本地函数合并到函数区；兼容旧版时调用必须在第一个本地函数定义之前。去重并保留原代码。
- 现有文件是 .mlx / .mlapp 或 userpath 为空、多目录时，先处理实际生效文件和目录。
- 不修改 MATLAB 安装目录 matlabrc.m，不改变当前工作目录。

```matlab
rehash; which('startup','-all'); startup;
```

首次应 PASS，已初始化时出现 already initialized 也正常。startup 只在 MATLAB 启动时执行，不会在 Windows 登录时打开 MATLAB，也不会在关闭 MATLAB 后保持连接。

## 7. 分层验收

1. 核对固定版本、文件存在、两个附加组件和 SATK PASS。
2. 确认 startup 路径及手动执行结果、17个技能连接有效、其他配置保留。
3. 保持 MATLAB 打开，重启 Codex 或新建重新加载配置的本地聊天。
4. 确认 MCP 列出14个工具（含 Simulink 扩展）。
5. 通过 evaluate_matlab_code 实际执行：
   ```matlab
   disp(version); disp(matlabroot); disp(ver('simulink')); which('startup','-all'); disp(which('simviewers.slx'));
   ```
6. 将上一步返回的真实 .slx 路径传给 model_overview，scope=root、detail=tree。不要假设 which('vdp') 返回模型，它可能是 .m。
7. 同时检查 isError 和文本内 status:error 等业务错误。
8. 下次正常启动 MATLAB 时观察自动初始化输出，不强制关闭用户现有工作。

安装文件存在、能列工具、能执行工具是三个不同层级，不能混为一谈。

## 故障经验

本次受限终端能完成 MCP 握手和列工具，但实际执行报 failed to attach to MATLAB session。进一步发现 connector 端口可达，而读取 %APPDATA%\MathWorks\MATLAB MCP Server\v1\sessionDetails.json 被拒绝。该文件含会话凭据，不要输出、复制进仓库或提交。

重启 Codex 后，其原生 MATLAB MCP 已成功执行查询和模型概览。遇到类似问题，检查运行环境、会话发现文件访问权和本机连接权限，按正常权限流程处理；不绕过审批。端口是动态值，不要固定31515。

## 官方资料

- [统一安装器](https://github.com/matlab/agentic-toolkit-installer)
- [MATLAB Agentic Toolkit](https://github.com/matlab/matlab-agentic-toolkit)
- [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server)
- [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit)
- [MATLAB startup](https://www.mathworks.com/help/matlab/ref/startup.html)
- [Codex MCP](https://developers.openai.com/codex/mcp)

本机实际结果见 [2026-10-26 验收记录](VERIFICATION-2026-10-26.md)。
