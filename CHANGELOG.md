# 更新日志

## v0.3.1

- 修复「打开完整控制台」首次打开报 `{"error":"管理接口仅允许本机同源访问"}`：
  浏览器给本机地址附带 `android-app://` 这类非 http 的 Referer 时，上游的同源围栏
  会以 `referer-invalid` 返回 403（手动在地址栏回车因来源变成自身而通过）
- 点按钮时先把地址写入剪贴板，再用 VIEW intent 投递；失败时提示粘贴打开
- 拷贝统一走 `copyText`，剪贴板 API 不可用时回退 `execCommand`

## v0.3.0

- WebUI 新增「控制台」区块：推理服务状态、渠道模块、EAC 授权、可用模型计数、
  刷新间隔、输出上限、目录同步时间
- 新增 `ofmctl.sh console`：用本机 API Key 临时换取会话后读取 `/api/management/summary`，
  cookie 写入临时文件、用完即删，Key 不经 URL
- 「打开完整控制台」交给系统浏览器：管理页带 `frame-ancestors 'none'`，无法在 WebView 内嵌

## v0.2.2

- 修复 PID 被复用导致的状态误判：`is_running` 除 `kill -0` 外再核对 `/proc/<pid>/cmdline`，
  避免把别的进程当成服务，从而 `start` 直接返回、服务实际已停
- `stop` 在服务已不在时也会清理残留的 pidfile、FIFO 与 service.lock

## v0.2.1

- 日志每行前面加时间戳，格式 `10/23-22:46:15`
- 服务输出改经 FIFO 后写入日志，node 仍以真实 PID 运行，启停不受影响

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
