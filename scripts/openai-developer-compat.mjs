#!/usr/bin/env node
/**
 * 构建期的 OpenAI 兼容修补：让 /v1/chat/completions 接受 `role: "developer"`。
 *
 * 为什么需要：
 *   上游网关的 chat/completions 入口只认 system / user / assistant / tool 四个角色，
 *   收到 `developer` 直接回 400（"unsupported message role: developer"）。
 *   而新版客户端（DSH 的 pi-ai 适配层）对自定义 baseURL 会把握手用的系统提示
 *   发成 `developer`，于是第一个请求就被拒，表现为「一句话都发不出去」。
 *   上游自己的 /v1/responses 入口本来就接受 developer（折成 system），
 *   所以这只是 chat/completions 这条路的缺口，这里按同样的语义补齐。
 *
 * 改法：`if (role === "system")` → `if (role === "system" || role === "developer")`。
 *   内容处理不用动：developer 的 content 是字符串或 `[{type:"text"}]`，
 *   与 system 走同一个 textFromContent，语义完全一致。
 *
 * 幂等：已经补过的形态会被认出来并跳过，`--app` 复用同一目录时不会失败。
 * 严格：锚点找不到就退出 1，宁可构建失败，也不出一个「看起来修了」的包。
 *
 * 用法：node scripts/openai-developer-compat.mjs <app 目录>
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import path from 'node:path'

const app = process.argv[2]
if (!app) {
  console.error('用法：node scripts/openai-developer-compat.mjs <app 目录>')
  process.exit(1)
}

const fail = message => {
  console.error(`openai-developer-compat: ${message}`)
  process.exit(1)
}

// 原始锚点；同时带上「已修补」形态，用于识别重复执行
const ANCHOR_RAW = '  if (role === "system") {'
const ANCHOR_PATCHED = '  if (role === "system" || role === "developer") {'
const PATCHED_LINE = '  if (role === "system" || role === "developer") {'

/**
 * 补一个文件。required=true 时找不到锚点即失败；否则只报告跳过。
 * @returns {'patched' | 'already' | 'skipped'}
 */
function patchFile(rel, required) {
  const file = path.join(app, rel)
  if (!existsSync(file)) {
    if (required) fail(`找不到 ${file}`)
    console.log(`openai-developer-compat: 跳过 ${rel}（文件不存在）`)
    return 'skipped'
  }

  const source = readFileSync(file, 'utf8')
  if (source.includes(ANCHOR_PATCHED)) {
    console.log(`openai-developer-compat: ${rel} 已经是修补后的形态，跳过`)
    return 'already'
  }

  // 只替换 convertMessage 里那一处：它前面紧跟着 `const role = value.role;`
  // 这个上下文一起匹配，避免误伤文件里另外几处 `if (message.role === "system")`
  const context = `  const role = value.role;\n${ANCHOR_RAW}`
  const hits = source.split(context).length - 1
  if (hits !== 1) {
    if (required) {
      fail(`在 ${rel} 里找到 ${hits} 处锚点（期望 1 处）。上游结构可能变了，需要重新确认锚点`)
    }
    console.log(`openai-developer-compat: ${rel} 找到 ${hits} 处锚点，跳过`)
    return 'skipped'
  }

  const next = source.replace(context, `  const role = value.role;\n${PATCHED_LINE}`)
  writeFileSync(file, next)
  console.log(`openai-developer-compat: 已修补 ${rel}（developer 角色折成 system）`)
  return 'patched'
}

// 真正被运行时加载的是 packages/standalone/channels/business.mjs；
// vendor/channel-pack/pack.js 是同一份代码的打包产物（当前不被 import，
// 但升级器把它当作运行时资产维护），存在就一起补，保持两边一致。
const required = patchFile('packages/standalone/channels/business.mjs', true)
patchFile('vendor/channel-pack/pack.js', false)

if (required !== 'patched' && required !== 'already') {
  fail('business.mjs 没有打上补丁')
}
console.log('openai-developer-compat: 完成')
