# 2026-10-26 本机验收记录

以下路径仅为本机实例，不能直接复制到另一台电脑。

| 项目 | 实际结果 |
| --- | --- |
| MATLAB | 26.2.0.3386108 (R2026b) |
| MATLAB 根目录 | D:\Code\Matlab |
| Simulink | 26.2 (R2026b) |
| 工具包根目录 | C:\Users\wl\Documents\Codex\MathWorks-Agentic-Toolkits\v1 |
| startup | C:\Users\wl\Documents\MATLAB\startup.m |
| 安装器 | v0.2.0 |
| MATLAB Agentic Toolkit | MATK-2026.10.b |
| MATLAB MCP Server | v0.15.0 |
| Simulink Agentic Toolkit | SATK-2026.10.c |
| 技能 | MATLAB Core 6个 + Model-Based Design Core 11个 |
| MCP 工具 | 14个，包含 Simulink 扩展 |

## 已通过

- 原 Codex 配置先备份，只新增 matlab MCP 服务；原配置内容保持完整。
- 原无 startup，在 MATLAB 确认的 userpath 新建自动初始化脚本，使用实际工具包根目录。
- 默认 AppData 工具包目录拒绝写入，使用持久的 Documents/Codex 目录安装。
- 命令行附加组件注册失败后，由用户在正常打开的 MATLAB 完成两个附加组件安装。
- SATK Installation Check：PASS。Simulink 已安装并许可、9个工具入口在路径上、shareMATLABSession 可用、connector 正在运行。
- codex mcp get matlab 解析配置成功。
- MCP initialize 和 tools/list 成功，列出14个工具。
- 重启 Codex 后，原生 evaluate_matlab_code 实际返回上述 MATLAB 版本、根目录、Simulink 版本和 startup 路径。
- model_overview 实际读取 D:\Code\Matlab\toolbox\simulink\blocks\library\simviewers.slx，参数 scope=root、detail=tree，返回：

~~~text
blk_0 simviewers [1 | 0/0]
0 Containers (0 internal, 0 external) | depth 0
note: Model has no inline graphical containers
~~~

工具返回内容无业务错误，代码执行及模型概览端到端验收通过。

## 排障记录

受限终端启动 MATLAB 报 File system inconsistency；同一机器的正常 MATLAB 可用，因此未判定许可证故障、未重装 MATLAB。

受限终端能列 MCP 工具，但 evaluate_matlab_code / model_overview 报 failed to attach to MATLAB session。本机 connector 端口可达，共享会话发现文件读取被拒绝；权限申请后仍受限，正常权限重试也被当时策略拒绝。重启 Codex 后，已加载的原生 MATLAB MCP 实际调用成功。

未上传原始用户配置备份、会话发现文件、凭据、官方工具包二进制或本机完整日志。

## 仍待自然验证

手动运行 startup 已 PASS；未强制关闭用户 MATLAB 会话。下次正常启动 MATLAB 时，仍需观察自动初始化输出，才能确认启动时自动执行。
