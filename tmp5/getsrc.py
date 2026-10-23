import json
import urllib.request

BASE = "http://127.0.0.1:8787/mcp"
SID = "probe1"
counter = [30000]


def call(name, args, timeout=600):
    counter[0] += 1
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": counter[0],
        "method": "tools/call",
        "params": {"name": name, "arguments": args},
    }).encode()
    req = urllib.request.Request(BASE, data=body, headers={
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "mcp-session-id": SID,
    })
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)["result"]["structuredContent"]


APK = "/storage/emulated/0/MT2/OFM 本机网关_0.1.0.apk"
BUILD = "/storage/emulated/0/MT2/ofm-src"

# 解出完整 app 源码，用来分析 abort 与调度逻辑
for d in ("", "/app"):
    call("mt_file_create_directory", {"path": BUILD + d})

# 用 zip_extract 解出 assets/runtime-arm64.tgz 后再拆包
# 先拿运行时包
res = call("mt_zip_extract", {
    "path": APK,
    "entries": [{"entryPath": "assets/runtime-arm64.tgz",
                 "destinationPath": "/storage/emulated/0/MT2/ofm-src/runtime.tgz"}],
    "overwrite": True,
    "password": "",
})
print("extract tgz:", res.get("ok"))
