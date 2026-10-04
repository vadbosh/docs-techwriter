import type { Plugin } from "@opencode-ai/plugin"

// docs-check OpenCode plugin — after an edit to documentation, runs the
// docs-techwriter greps on the lines the edit wrote and appends what they found
// to the tool's output, where the model reads it.
//
// The checks live in one program, skills/docs-techwriter/scripts/docs_check.py,
// shared with the Claude Code and Codex hooks; this plugin only reshapes
// Opencode's arguments into the payload that program reads, and runs it with
// --text. It never blocks: a missing python3 or a failure leaves the edit as is.

const SCRIPT = `${process.env.HOME ?? ""}/.config/opencode/skills/docs-techwriter/scripts/docs_check.py`

export const DocsCheckPlugin: Plugin = async ({ $, directory }) => {
  return {
    "tool.execute.after": async (input, output) => {
      const tool = String(input?.tool ?? "").toLowerCase()
      const args = (input as { args?: Record<string, unknown> })?.args ?? {}
      let payload: Record<string, unknown> | undefined
      if (tool === "edit" && typeof args.filePath === "string") {
        payload = { tool_name: "Edit", tool_input: { file_path: args.filePath, new_string: String(args.newString ?? "") } }
      } else if (tool === "write" && typeof args.filePath === "string") {
        payload = { tool_name: "Write", tool_input: { file_path: args.filePath, content: "" } }
      } else if (tool === "apply_patch" && typeof args.patchText === "string") {
        payload = { tool_name: "apply_patch", tool_input: { patchText: args.patchText }, cwd: directory }
      }
      if (!payload) return
      const res = await $`printf %s ${JSON.stringify(payload)} | python3 ${SCRIPT} --text`.quiet().nothrow()
      const note = String(res.stdout ?? "").trim()
      if (res.exitCode === 0 && note) output.output = `${output.output ?? ""}\n\n${note}`
    },
  }
}
