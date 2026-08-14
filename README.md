# AlecaFrame 简体中文补丁

个人再度精修，基本常用功能的都汉化完了，搜索框也加了任意中文字段识别，可能有些小问题可以提交反馈(随缘修)

已在 AlecaFrame 2.6.90、Overwolf 0.305.0.9 上验证。

界面词库覆盖约 1,060 条菜单、按钮、设置、提示、交易、遗物、裂罅、配装模拟与小队文本。Warframe 专有名词采用国际服简体中文用语；国际服仍使用英文的战甲名称（例如 Ash、Atlas）会保持原名。

## 安装

双击 `Install.cmd`，桌面会出现“**AlecaFrame-ZH**”快捷方式。

安装补丁前，需要先在 Overwolf 中正常安装并打开一次官方 AlecaFrame。

以后通过该快捷方式启动中文版。首次打开大约需要 20 秒，因为启动器会：

1. 从官方 OPK 缓存或本地官方备份恢复原版界面；若 OPK 缓存不存在，首次运行会自动备份当前未修改的官方文件；
2. 启动并让 Overwolf 完成原版完整性校验；
3. 在当前会话注入中文界面并重载 AlecaFrame。

也可以直接双击 `Start-Chinese.cmd`。

## 恢复英文 / 卸载

双击 `Uninstall.cmd`。它会关闭 Overwolf、恢复官方界面文件并移除 `AlecaFrame-ZH` 桌面快捷方式。

## 重要说明

- 官方 `app.opk`、官方签名、DLL、账号数据和 Warframe.Market 登录令牌均不会被修改。
- 启动器会从 Windows 安装信息自动查找 Overwolf，不依赖固定盘符或安装目录。
- 为让已通过校验的页面从磁盘加载中文，本启动器会在该次 Overwolf 会话使用：
  `--ow-disable-features=extension-validation,read-opk-from-memory`
- 该参数作用于本次 Overwolf 会话；启动中文版时会先关闭已有的 Overwolf。
- AlecaFrame 更新后，启动器会自动选择最新安装版本。若新版大幅修改界面，新增文字可能暂时保持英文。

## 原作者

想吃西瓜（QQ：191086215）

## 开源协议

本项目采用 [MIT License](LICENSE) 开源。
