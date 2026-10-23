# OFM 本机网关 · Magisk / KernelSU 模块

把 [Our Free Model](https://github.com/Ebony-Vinyl/dsh-our-free-model) 的本地网关做成系统级模块：
**开机以 root 常驻运行，不需要安装那个 App，也不需要它在后台待着。**

> 作者酷安主页：<https://www.coolapk.com/u/3214953>

---

## 为什么做这个

上游的 `Our Free Model` 自带一个本地网关，但它是跟着 APK 跑的：App 被系统杀掉、被清理后台、
或者你压根不想装它时，网关就没了。这个模块把同一套服务搬到 Magisk / KernelSU 层：

- 开机由 root 拉起，不占前台、不弹通知、不参与保活竞争
- 只要手机活着，`127.0.0.1:15656` 就一直在
- 数据放在独立目录，与 App 的数据互不干扰

## 特性

| 特性 | 说明 |
| --- | --- |
| **独立运行** | 模块自带 Node 运行时与完整服务，APK 可以完全不装 |
| **开机自启** | KernelSU / Magisk 在 boot 阶段拉起，可随时关闭 |
| **端口固定** | 默认 `15656`，被占用时自动顺延并记住实际端口 |
| **WebUI 管理** | KernelSU 里点「打开」即可查看状态、启停、改配置、看日志 |
| **动作按钮** | 没有 WebUI 时也能在管理器里点「动作」操作 |
| **数据独立** | 全部落在 `/data/adb/ofm`，与 App 数据隔离 |
| **更新检测** | 通过 `update.json` 支持管理器内直接检查更新 |

## 安装

1. 到 [Releases](../../releases) 下载最新版 `OFM_Gateway_Magisk_v<版本>.zip`
2. 在 KernelSU / Magisk 模块页面选「从本地安装」，选中该 zip
3. 重启手机

模块安装时已解好运行时，重启后服务会自动起来。确认状态：

```sh
su -c 'sh /data/adb/modules/ofm_gateway/common/ofmctl.sh status'
```

输出会给出 pid、地址、API Key 与日志路径。

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

```http
Authorization: Bearer <你的 Key>
```

Key 由服务首次启动时自动生成并存入 `/data/adb/ofm/settings.json`，重启不变。
在 WebUI 或动作按钮里都能直接看到。

## WebUI

在 KernelSU 管理器里点模块的「打开」进入（需要 KernelSU，Magisk 无此功能）。

页面通过 `ksu.exec` 调用 `common/ofmctl.sh`，不额外监听端口，也不直接请求网关接口：

- **状态**：运行中 / 未运行、PID、地址、API Key（点一下复制）、运行时版本
- **操作**：启动 / 停止 / 重启
- **配置**：端口、监听地址、开机自启，可「保存」或「保存并重启」
- **控制台**：推理服务、渠道模块、EAC 授权、可用模型计数、刷新间隔、输出上限、目录同步时间
- **日志**：`ofm.log` 最后 60 行

页面地址与 Key 均支持点击复制。完整管理面板（渠道登录、用量看板、Key 轮换）带
`frame-ancestors 'none'` 与 HttpOnly 会话，无法内嵌，请复制地址到浏览器打开后粘贴 Key 登录。

写入值有严格校验：端口只能是 0–65535 的整数、地址只允许 `127.0.0.1` / `0.0.0.0`、
自启只允许 0/1；`set-config` 只做整行替换，不把输入拼接进 shell。

## 配置

编辑 `/data/adb/modules/ofm_gateway/config.sh`，然后在动作按钮里选「重启服务」生效。

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `PORT` | `15656` | 监听端口。填 `0` 则沿用服务自己记住的端口 |
| `HOST` | `127.0.0.1` | 监听地址。局域网访问改成 `0.0.0.0` |
| `AUTOSTART` | `1` | 开机自启，`0` 关闭 |
| `DATA_DIR` | `/data/adb/ofm` | 数据目录 |

> **注意**：改成 `0.0.0.0` 会让同网段的设备也能用你的额度，请仅在可信网络启用。

## 常用命令

```sh
CTL=/data/adb/modules/ofm_gateway/common/ofmctl.sh
su -c "sh $CTL status"     # 运行状态
su -c "sh $CTL start"      # 启动
su -c "sh $CTL stop"       # 停止
su -c "sh $CTL restart"    # 重启
su -c "sh $CTL log 80"     # 最近 80 行日志
su -c "sh $CTL info"       # 机器可读状态（WebUI 用）
```

## 文件都在哪

| 路径 | 内容 |
| --- | --- |
| `/data/adb/modules/ofm_gateway` | 模块本体（脚本、运行时压缩包、webroot） |
| `/data/adb/ofm-runtime` | 解压出来的 Node 运行时与服务代码 |
| `/data/adb/ofm` | 数据：`settings.json`、`stats.json`、`ofm.log` 等 |
| `/data/adb/ofm/ofm.log` | 服务日志，含管理面板一次性登录链接 |

运行时放在 `/data/adb/ofm-runtime` 而不是模块目录，是因为模块升级时旧目录会被整体清理，
正在运行的进程会被一并杀掉。

## 卸载

在模块页面移除即可。卸载脚本会先停服务、再删 `/data/adb/ofm-runtime`，
**不会**动 `/data/adb/ofm` 里的数据与 Key；要彻底清干净请手动删掉该目录。

## 更新

模块通过 `update.json` 向 KernelSU / Magisk 上报新版本，管理器会提示更新。

- 当前版本：见 `module/module.prop` 的 `version`
- 变更记录：[CHANGELOG.md](CHANGELOG.md)

## 从源码构建

仓库**不含**运行时二进制（37 MB），构建时从官方 APK 中提取：

```sh
./scripts/build.sh "/path/to/OFM 本机网关_0.1.0.apk"
```

产物为 `dist/OFM_Gateway_Magisk_<version>.zip`。

构建前脚本会校验：

- `module.prop` 必需键齐全（`id`/`name`/`version`/`versionCode`/`author`/`description`）
- `update.json` 的 `version` / `versionCode` 与 `module.prop` 一致

任一项不符直接报错，避免推出错版本或让管理器反复提示更新。

### 发版流程

1. 改 `module/module.prop`：调高 `version` 与 `versionCode`
   （**`versionCode` 必须是递增整数**，管理器只按它比新旧）
2. 改 `update.json`：同步版本号，`zipUrl` 换成本次 Release 附件直链
3. 更新 `CHANGELOG.md`
4. 构建、打 tag、发 Release、上传 zip

注意事项：

- `zipUrl` 必须指向 **Release 附件**，不能指向仓库源码 zip（源码包没有 `runtime/`，刷入会失败）
- `raw.githubusercontent.com` 有约 5 分钟 CDN 缓存，改完 `update.json` 不会立刻生效
- 若改动了 `customize.sh` 的解压逻辑，需递增 `runtime/.version`，否则已解压的设备不会重新解压
- 仓库必须公开，否则管理器取不到 `update.json`

## 说明

- 本模块只是把上游 [dsh-our-free-model](https://github.com/Ebony-Vinyl/dsh-our-free-model)
  的 standalone 服务搬到 Android 系统层运行；模型能力与其限制（额度、地区、上游条款）与上游一致。
- 免费模型的可用性由上游决定，模块不介入也无法保证。
- 模块不收集任何数据，也不联网上报；所有状态都在 `/data/adb/ofm`。
- 与任何模型提供方无隶属或背书关系。

## License

MIT
