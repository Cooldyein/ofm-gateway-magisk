# OFM 本机网关 · Magisk / KernelSU 模块

把 [Our Free Model](https://github.com/Ebony-Vinyl/dsh-our-free-model) 的本地网关做成系统级模块：
开机以 root 常驻运行，不需要安装那个 App，也不需要它在后台待着。

- **独立运行**：模块自带 Node 运行时与完整服务，APK 可以完全不装。
- **开机自启**：由 KernelSU / Magisk 在 boot 阶段拉起，不占前台、不弹通知。
- **端口固定**：默认 `15656`，不跟 App 抢 18900；被占用时服务自动顺延并记住实际端口。
- **一条命令查看**：点模块的「动作」按钮即可看到地址、API Key，并能启停 / 重启。
- **数据独立**：全部落在 `/data/adb/ofm`，与 App 的数据互不干扰。

作者酷安主页：<https://www.coolapk.com/u/3214953>

## 它提供什么

服务启动后在本机暴露 OpenAI 兼容接口：

| 用途 | 地址 |
| --- | --- |
| 模型清单 | `GET http://127.0.0.1:15656/v1/models` |
| 对话补全 | `POST http://127.0.0.1:15656/v1/chat/completions` |
| Responses API | `POST http://127.0.0.1:15656/v1/responses` |
| Anthropic Messages | `POST http://127.0.0.1:15656/v1/messages` |
| 存活探针 | `GET http://127.0.0.1:15656/health` |

除 `/health` 外都需要带上 API Key：

```
Authorization: Bearer <你的 Key>
```

Key 由服务首次启动时自动生成并存进 `/data/adb/ofm/settings.json`，重启不会变。
点模块的「动作」按钮就能直接看到当前地址与 Key。

服务的完整能力（模型清单、渠道账号、用量看板、EAC 渠道等）沿用上游项目，
这里只是把它从 App 里搬到了系统层。管理面板的一次性登录链接在日志中：

```
/data/adb/ofm/ofm.log
```

## 安装

1. 从 Releases 下载最新版的 `OFM_Gateway_Magisk_v<版本>.zip`。
2. 在 KernelSU / Magisk 的模块页面选「从本地安装」，选中这个 zip。
3. 重启手机。模块安装时已经解好运行时，重启后服务会自动起来。

确认是否正常：

```sh
su -c 'sh /data/adb/modules/ofm_gateway/common/ofmctl.sh status'
```

输出里会给出 pid、地址、Key 与日志路径。

## 配置

改 `/data/adb/modules/ofm_gateway/config.sh`，然后在动作按钮里选「重启服务」生效。

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `PORT` | `15656` | 监听端口。填 `0` 则沿用服务自己记住的端口 |
| `HOST` | `127.0.0.1` | 监听地址。要局域网访问改成 `0.0.0.0` |
| `AUTOSTART` | `1` | 开机自启开关，`0` 关闭 |
| `DATA_DIR` | `/data/adb/ofm` | 数据目录 |

## 文件都在哪

| 路径 | 内容 |
| --- | --- |
| `/data/adb/modules/ofm_gateway` | 模块本体（脚本、运行时压缩包） |
| `/data/adb/ofm-runtime` | 解压出来的 Node 运行时与服务代码 |
| `/data/adb/ofm` | 数据：`settings.json`、`stats.json`、`ofm.log` 等 |
| `/data/adb/ofm/ofm.log` | 服务日志，含管理面板登录链接 |

运行时之所以放在 `/data/adb/ofm-runtime` 而不是模块目录，是因为模块升级时旧目录会被
整体清理，正在运行的进程会被一并杀掉。

## 卸载

在模块页面移除即可。卸载脚本只删 `/data/adb/ofm-runtime`，
**不会**动 `/data/adb/ofm` 里的数据与 Key；要彻底清干净就手动删掉这个目录。

## 从源码构建

仓库不含运行时二进制（37 MB），构建时从 APK 里取：

```sh
# 把 OFM 本机网关的 APK 放在仓库同级目录，然后：
./scripts/build.sh "/path/to/OFM 本机网关_0.1.0.apk"
```

产物为 `dist/OFM_Gateway_Magisk_<version>.zip`。

脚本会先核对 `update.json` 与 `module/module.prop` 的 `version` / `versionCode`，
不一致时直接报错——否则管理器会推错版本或反复提示更新。

## WebUI

在 KernelSU 管理器里点模块的「打开」即可进入页面（需要 KernelSU，Magisk 没有这个功能）。

页面通过 `ksu.exec` 调用 `common/ofmctl.sh`，不自己起 HTTP 服务，也不直接请求网关接口：

- **状态**：运行中 / 未运行、PID、地址、API Key（点一下复制）、运行时版本
- **操作**：启动 / 停止 / 重启
- **配置**：端口、监听地址、开机自启；可「保存」或「保存并重启」
- **日志**：`ofm.log` 最后 60 行

页面对写入值做严格校验（端口只能是 1–65535 的整数、地址只允许 `127.0.0.1` / `0.0.0.0`、自启只允许 0/1），
`set-config` 也只做整行替换、不把输入拼接进 shell。

`webroot/` 的权限与 SELinux 上下文由 KernelSU 安装时自动设置，构建脚本不会改它。

## 发版

模块通过 `update.json` 向 KernelSU / Magisk 上报新版本（`module.prop` 的 `updateJson` 指向它）。
每次发版改三处，再打 Release：

1. `module/module.prop`：调高 `version` 与 `versionCode`（**`versionCode` 必须是递增整数**，管理器只按它比新旧）
2. `update.json`：同步 `version` / `versionCode`，把 `zipUrl` 换成本次 Release 附件的直链
3. `CHANGELOG.md`：写本次改动

然后执行构建并把 zip 传到对应的 Release 附件。注意：

- `zipUrl` 必须指向 **Release 附件**，不能指向仓库源码 zip——源码包里没有 `runtime/`，刷入会失败。
- `raw.githubusercontent.com` 有约 5 分钟 CDN 缓存，改完 `update.json` 不会立刻生效。
- 如果改动了 `customize.sh` 的解压逻辑，记得递增 `runtime/.version`，否则已解压过的设备不会重新解压。
- 仓库必须公开，否则管理器取不到 `update.json`。

## 说明

- 本模块只是把上游项目 [dsh-our-free-model](https://github.com/Ebony-Vinyl/dsh-our-free-model)
  的 standalone 服务搬到 Android 系统层运行，模型能力与其限制（额度、地区、上游条款）与上游一致。
- 免费模型的可用性由上游决定，模块不介入也无法保证。
- 模块不收集任何数据，也不联网上报；所有状态都在 `/data/adb/ofm`。

## License

MIT
