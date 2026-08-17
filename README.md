# AlecaFrame 简体中文补丁

已在 AlecaFrame 2.6.90、Overwolf 0.305.0.9 上验证。

界面词库覆盖约 1,060 条菜单、按钮、设置、提示、交易、遗物、裂罅、配装模拟与小队文本。Warframe 专有名词采用国际服简体中文用语；国际服仍使用英文的战甲名称（例如 Ash、Atlas）会保持原名。

## 安装

新用户请优先阅读 [安装教程](安装教程.md)。先运行 `Install.cmd`；如需中文遗物推荐和奖励选择识别叠加层，再运行 `安装OCR前置组件.cmd`。桌面会出现“**AlecaFrame-ZH**”快捷方式。

安装补丁前，需要先在 Overwolf 中正常安装并打开一次官方 AlecaFrame。

以后通过该快捷方式启动中文版。首次打开大约需要 20 秒，因为启动器会：

1. 从官方 OPK 缓存或本地官方备份恢复原版界面；若 OPK 缓存不存在，首次运行会自动备份当前未修改的官方文件；
2. 启动并让 Overwolf 完成原版完整性校验；
3. 在当前会话注入中文界面并重载 AlecaFrame。

也可以直接双击 `Start-Chinese.cmd`。

`安装OCR前置组件.cmd` 是可选增强组件：它会把 Python、Node.js、PaddlePaddle、PaddleOCR 与中文模型安装到项目的 `.tools` 目录，不修改系统全局 Python 或 Node.js。未安装时主程序仍可运行，只是不提供中文遗物 OCR 叠加层。下载使用华为云、npmmirror、阿里云 PyPI 和 PaddlePaddle 国内镜像；已安装后可通过 `关闭中文遗物OCR.cmd` 停用，以消除其运行时截图和识别开销。

## 兼容性诊断

当其他用户反馈遗物推荐或奖励选择叠加层不显示、识别错误或速度异常时，运行 `生成兼容性诊断报告.cmd`。

它只读取运行状态和最近 OCR 审计记录，不截图、不调用 OCR、不会改变两个叠加层的行为。报告默认生成在：

`%LOCALAPPDATA%\AlecaFrame-ZH-Patch\CompatibilityReports`

反馈时请同时提供生成的 JSON、问题发生时的完整游戏截图，以及游戏分辨率、HUD 缩放、显示模式、HDR 和是否超宽屏。

如需把排错资料一次性打包，双击 `导出诊断包.cmd`。它会在桌面生成 ZIP，包含每类最近 20 张已有诊断截图、`bridge-audit.log` 最近 500 行、启动日志、最新运行状态和最近一份兼容性报告；它不会重新截图、不会运行 OCR，也不会修改叠加层设置。

`bridge-audit.log` 会自动轮换：超过 5 MB 时仅保留最近约 2 MB 的记录，因此可长期保留近期排错信息而不会无限增长。

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
