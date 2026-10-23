# 更新日志

## v0.2.0

- 新增 KernelSU WebUI 管理页面：状态、启停 / 重启、端口与监听地址、开机自启、日志查看
- WebUI 通过 `ksu.exec` 调用 `ofmctl.sh`，不额外监听端口
- `ofmctl.sh` 新增 `info`、`set-config`、`log` 三个子命令
- 构建脚本会核对 `update.json` 与 `module.prop` 的版本是否一致

## v0.1.0

首个版本。

- 模块自带 Node 运行时与 Our Free Model standalone 服务，无需安装 App
- 开机由 KernelSU / Magisk 拉起，以 root 常驻运行
- 默认监听 `127.0.0.1:15656`，端口被占用时自动顺延并记住
- 动作按钮可查看地址与 API Key，并启停 / 重启服务
- 数据独立存放于 `/data/adb/ofm`，与 App 数据互不干扰
