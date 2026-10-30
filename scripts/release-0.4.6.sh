#!/system/bin/sh
# v0.4.6 发版：push main + tag，再用 REST API 建 Release 并上传两个 zip。
#
# 前置：需要一个有 Cooldyein/ofm-gateway-magisk 写权限的 GitHub PAT。
# 本机当前没有可用凭据（git credential helper / ssh key 都没有），
# 运行前请先 export GITHUB_TOKEN，或在本脚本里临时填入（切勿提交该值）。
#
# 用法：
#   GITHUB_TOKEN=github_pat_xxx sh scripts/release-0.4.6.sh
#
# 说明：与 .aicode/memory 里旧的 aicode 容器流程不同，这里是 DSH Android 环境，
# 没有 credential helper；因此直接走 https + Bearer token。

set -e
ROOT=$(cd "${0%/*}/.." && pwd)
OWNER=Cooldyein
REPO=ofm-gateway-magisk
TAG=v0.4.6
VER=0.4.6
FULL="$ROOT/dist/OFM_Gateway_Magisk_v${VER}.zip"
PATCH="$ROOT/dist/OFM_Gateway_Magisk_v${VER}_patch.zip"

[ -n "$GITHUB_TOKEN" ] || { echo "缺少 GITHUB_TOKEN 环境变量" >&2; exit 1; }
[ -f "$FULL" ]  || { echo "缺少 $FULL（先在 dist 构建）" >&2; exit 1; }
[ -f "$PATCH" ] || { echo "缺少 $PATCH（先在 dist 构建）" >&2; exit 1; }

cd "$ROOT"

echo "== 1. push main =="
git -c safe.directory='*' push \
  "https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/${REPO}.git" main

echo "== 2. push tag $TAG =="
git -c safe.directory='*' push \
  "https://x-access-token:${GITHUB_TOKEN}@github.com/${OWNER}/${REPO}.git" "$TAG"

echo "== 3. 建 Release =="
RELEASE_JSON=$(python3 - "$OWNER" "$REPO" "$TAG" "$VER" <<'PY'
import json, os, sys, urllib.request
owner, repo, tag, ver = sys.argv[1:5]
token = os.environ["GITHUB_TOKEN"]
body = """同步上游到 2.7.3，并回到「不带模型工作台引擎」的纯上游形态。

- 移除试做的 magpie 工作台引擎（engine.json / engine-fetch / dnsproxy / magpie-engine-overlay）与渠道桥（bridge/、channel-overlay.mjs），回到纯上游基线
- 上游服务同步到 2.7.3
- 模块行为与安装方式不变，默认端口 15656
- 保留 openai-developer-compat 补丁（chat/completions 接受 developer 角色）

详见 CHANGELOG.md。"""
req = urllib.request.Request(
    f"https://api.github.com/repos/{owner}/{repo}/releases",
    data=json.dumps({
        "tag_name": tag, "target_commitish": "main",
        "name": f"OFM 本机网关 v{ver}",
        "body": body, "draft": False, "prerelease": False,
    }).encode(),
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "ofm-release-script",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as r:
    print(r.read().decode())
PY
)
echo "$RELEASE_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("release id:",d["id"]); print("upload_url:",d["upload_url"])'
UPLOAD_URL=$(echo "$RELEASE_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["upload_url"].split("{")[0])')

echo "== 4. 上传附件 =="
for f in "$FULL" "$PATCH"; do
  name=$(basename "$f")
  echo "-- upload $name"
  curl -s -X POST "${UPLOAD_URL}?name=${name}" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/zip" \
    -H "User-Agent: ofm-release-script" \
    --data-binary "@$f" \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print("state:",d.get("state"),"size:",d.get("size"),"url:",d.get("browser_download_url"))'
done

echo "== 5. 完成。稍等约 5 分钟等 raw.githubusercontent 缓存刷新，再核对 update.json =="
