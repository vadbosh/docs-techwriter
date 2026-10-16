import { spawn } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

// docs-check OpenCode plugin — after an edit to documentation, runs the
// docs-techwriter greps on the lines the edit wrote and appends what they found
// to the tool's output, where the model reads it.
//
// The checks live in one program, skills/docs-techwriter/scripts/docs_check.py,
// shared with the Claude Code and Codex hooks; this plugin only reshapes
// Opencode's arguments into the payload that program reads, and runs it with
// --text. It never blocks: a missing python3 or a failure leaves the edit as is.
//
// Dual-shape, like rtk.ts: OpenCode 2.x calls setup() and the file argument is
// `path`; 1.x calls server() and it is `filePath`.

const SCRIPT = `${process.env.HOME ?? ""}/.config/opencode/skills/docs-techwriter/scripts/docs_check.py`

function payloadFor(tool: unknown, args: any, directory: string): Record<string, unknown> | undefined {
  const t = String(tool ?? "").toLowerCase()
  const file = args?.path ?? args?.filePath
  if (t === "edit" && typeof file === "string") {
    return { tool_name: "Edit", tool_input: { file_path: file, new_string: String(args.newString ?? "") } }
  }
  if (t === "write" && typeof file === "string") {
    return { tool_name: "Write", tool_input: { file_path: file, content: "" } }
  }
  if (t === "apply_patch" && typeof args?.patchText === "string") {
    return { tool_name: "apply_patch", tool_input: { patchText: args.patchText }, cwd: directory }
  }
  return undefined
}

// The note the checks wrote, or "" when there is nothing to say.
function note(payload: Record<string, unknown>, timeout = 15000): Promise<string> {
  return new Promise((resolve) => {
    const p = spawn("python3", [SCRIPT, "--text"], { stdio: ["pipe", "pipe", "ignore"] })
    let out = ""
    const t = setTimeout(() => p.kill(), timeout)
    p.stdout.on("data", (d) => (out += d))
    p.on("error", () => (clearTimeout(t), resolve("")))
    p.on("close", (c) => (clearTimeout(t), resolve(c === 0 ? out.trim() : "")))
    p.stdin.on("error", () => {})
    p.stdin.end(JSON.stringify(payload))
  })
}

export const DocsCheckPlugin: Plugin = async ({ directory }: any) => ({
  "tool.execute.after": async (input: any, output: any) => {
    const payload = payloadFor(input?.tool, input?.args ?? {}, directory)
    if (!payload) return
    const text = await note(payload)
    if (text) output.output = `${output.output ?? ""}\n\n${text}`
  },
})

export default {
  id: "docs-check",
  async setup(ctx: any) {
    await ctx.tool.hook("execute.after", async (e: any) => {
      if (e?.status !== "completed") return
      const payload = payloadFor(e?.tool, e?.input ?? {}, ctx.location?.directory ?? process.cwd())
      if (!payload) return
      const text = await note(payload)
      if (!text) return
      const content: any[] = Array.isArray(e?.result?.content) ? e.result.content : []
      e.result = { ...e.result, content: [...content, { type: "text", text }] }
    })
  },
  server: DocsCheckPlugin,
}
