# 更新日志

## v0.1.0

首个版本。

- 模块自带 Node 运行时与 Our Free Model standalone 服务，无需安装 App
- 开机由 KernelSU / Magisk 拉起，以 root 常驻运行
- 默认监听 `127.0.0.1:15656`，端口被占用时自动顺延并记住
- 动作按钮可查看地址与 API Key，并启停 / 重启服务
- 数据独立存放于 `/data/adb/ofm`，与 App 数据互不干扰
