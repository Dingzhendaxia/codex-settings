# 目标电脑验收清单

此文件是通用清单，不代表目标电脑已经通过验收。实际路径和日志只保存在目标电脑，不提交到仓库。

- [ ] 已安装并可正常使用 Codex、MATLAB、Simulink，许可有效。
- [ ] 核对目标 MATLAB 版本及三个组件的兼容性、固定版本与官方来源。
- [ ] 安装输出无失败信息，status、可执行文件、两个 mltbx 和 Simulink tools.json 均已核对。
- [ ] 两个 MATLAB 附加组件已注册并启用。
- [ ] 原 Codex 配置已备份，其他配置保留；matlab 服务无重复段和占位符。
- [ ] matlab-core 6 个与 model-based-design-core 11 个技能均有效，冲突已处理。
- [ ] 已确认实际 userpath 与生效 startup；保留原启动逻辑。
- [ ] 正常启动 MATLAB 时自动初始化，Installation Check 为 PASS。
- [ ] codex mcp get matlab 成功；配置重载后可见预期 14 个工具，含 Simulink 扩展。
- [ ] 原生 evaluate_matlab_code 实际返回版本、matlabroot、Simulink 和 startup 信息。
- [ ] 原生 model_overview 成功读取实际返回的 .slx 路径，scope=root、detail=tree。
- [ ] 工具返回无 isError 或文本内业务错误。

安装完成、工具可见、实际连接成功是不同层级。未通过的项目必须注明原因，不能报告全部完成。

不要提交个人路径、原始用户配置、配置备份、完整日志、会话发现文件或凭据。
