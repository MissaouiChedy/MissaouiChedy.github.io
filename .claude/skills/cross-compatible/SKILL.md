---
name: cross-compatible
description: Rules for structuring agent context files (instructions, skills, agent roles, hooks, MCP config) so a single source works in both Claude Code and GitHub Copilot (VS Code, Copilot CLI, cloud agent). WHEN: "add an instruction", "add a rule", "create a skill", "add an agent", "new agent role", "add a hook", "add an MCP server", "make this work in Copilot", "make this work in Claude Code", or any edit to AGENTS.md, CLAUDE.md, .claude/, .github/, .vscode/hooks or .mcp.json.
---

# Cross-compatible agent context

Keep one source of truth per element, stored in Claude Code's layout under `.claude/`.
Copilot reaches it through native support, a symlink under `.github/`, or (hooks only) a
small per-harness config file that calls shared logic.

Verified against Claude Code, VS Code and GitHub docs on 2026-10-10. These products change
quickly: recheck the relevant row before relying on it for something new.

## Harnesses

| Short name | Product |
| --- | --- |
| claude | Claude Code (CLI and IDE extensions) |
| vscode | GitHub Copilot in VS Code (Local agent) |
| cli | GitHub Copilot CLI |
| cloud | Copilot cloud agent (runs on GitHub.com) |

## Layout

```
AGENTS.md                           canonical repo-wide instructions
CLAUDE.md                           one line: @AGENTS.md
.mcp.json                           MCP servers ("mcpServers")
.claude/
  rules/<topic>.instructions.md     path-scoped instructions
  skills/<name>/SKILL.md            skills, plus scripts/ and references/
  agents/<name>.agent.md            agent roles
  hooks/<name>.ps1                  hook logic, one script for every harness
  hooks/<name>.json                 Copilot-format hook config (cli, cloud)
  settings.json                     Claude Code hook config
.github/
  instructions -> ../.claude/rules  symlink
  skills       -> ../.claude/skills symlink (optional, see Skills)
  agents       -> ../.claude/agents symlink
  hooks        -> ../.claude/hooks  symlink
.vscode/
  settings.json                     restricts VS Code to its own hook files
  hooks/<name>.json                 VS Code-format hook config
```

## Who reads what

| Element | claude | vscode | cli | cloud |
| --- | --- | --- | --- | --- |
| `AGENTS.md` | only through the `@AGENTS.md` import | yes | yes | yes |
| `CLAUDE.md` | yes | yes (`chat.useClaudeMdFile`) | yes | yes |
| `.claude/rules/` | yes (`paths`) | yes (`paths`) | needs `.github/instructions` | needs `.github/instructions` |
| `.claude/skills/` | yes | yes | yes | yes |
| `.claude/agents/` | yes | yes (Claude format) | documented path is `.github/agents` | needs `.github/agents` |
| Hooks | `.claude/settings.json` | `.vscode/hooks/` (others disabled) | `.github/hooks/` **and** `.claude/settings.json` | `.github/hooks/` only |
| `.mcp.json` | yes | yes | yes | no, repository settings on GitHub.com |

## Symlinks

The `.github/*` entries are directory symlinks into `.claude/`, committed as git mode `120000`.

- On Linux and macOS, and in the cloud agent, they resolve with no setup.
- On Windows, git checks them out as plain text files unless symlinks are enabled
  (Developer Mode or admin rights, plus `git config core.symlinks true` before checkout, or
  `git clone -c core.symlinks=true`). A broken symlink fails silently: Copilot just finds no
  agents, instructions or hooks there.
- Create them with relative targets so they survive any clone location:
  `ln -s ../.claude/agents .github/agents` (Git Bash with symlinks enabled) or
  `New-Item -ItemType SymbolicLink -Path .github/agents -Target ../.claude/agents`.

## Instructions

**Repository-wide: `AGENTS.md` + `CLAUDE.md`.**

- Write all repository-wide guidance in `AGENTS.md`.
- `CLAUDE.md` contains only `@AGENTS.md`. Claude Code does not read `AGENTS.md` on its own; the
  import pulls it in. Copilot reads both files but does not expand `@` imports, so the line is inert.
- Do not put content in `CLAUDE.md` as well: Copilot loads both files, so anything there is
  duplicated or, worse, contradicts `AGENTS.md`.
- No `.github/copilot-instructions.md`: every Copilot agent surface already reads `AGENTS.md`.
  Exception: Copilot code review in VS Code reads only `copilot-instructions.md`. If that matters,
  add a one-line file pointing to `AGENTS.md`.

**Path-scoped: `.claude/rules/<topic>.instructions.md`.**

```markdown
---
description: Use when writing or changing JavaScript tests.
paths:
  - "tests/**/*.js"
applyTo: "tests/**/*.js"
---

Make sure to include negative cases as well.
```

- `.instructions.md` suffix: required by Copilot; Claude Code reads any `.md` under `.claude/rules/`.
- `paths` (YAML list) is read by Claude Code and by VS Code for Claude-format rules.
  `applyTo` (one string, comma-separated globs) is read by Copilot. Keep the two glob sets identical.
- `description` lets Copilot attach the file on demand when the task matches.
- Always-on guidance belongs in `AGENTS.md`, not in a rule without globs: Claude loads such a
  rule every time, but Copilot attaches it only when the description matches or a user adds it.

## Skills

Location: `.claude/skills/<name>/SKILL.md`. All four harnesses read `.claude/skills/` natively,
so the `.github/skills` symlink is optional; it only helps older Copilot clients.

**Frontmatter that works everywhere**

| Field | Rule |
| --- | --- |
| `name` | Required. Lowercase letters, digits, hyphens; max 64 chars; must equal the folder name (VS Code silently skips the skill otherwise). |
| `description` | Required. What it does and when to use it, max 1024 chars. Put trigger phrases inline (for example `WHEN: "generate an image", ...`), because `when_to_use` is Claude-only. |
| `argument-hint` | Optional. Hint shown after `/name`. |
| `user-invocable` | Optional. `false` hides it from the `/` menu. |
| `disable-model-invocation` | Optional. `true` makes it slash-command only. |
| `context: fork` | Optional. Runs in a subagent (experimental in VS Code). |

Claude-only fields, harmless elsewhere but with no effect there: `arguments`, `when_to_use`,
`allowed-tools`, `disallowed-tools`, `model`, `effort`, `paths`, `hooks`, `shell`, `agent`, `background`.
Never rely on them for behavior that must also hold in Copilot.

**Body**

- Argument substitution (`$ARGUMENTS`, `$0`, `$name` from `arguments`) is Claude-only. In Copilot
  the placeholder stays literal and the user's text arrives as extra context. Write the body so it
  still reads correctly unsubstituted, for example
  `Translate the sentence the user gave ($sentence) into the requested language ($language).`
- `` !`command` `` injection and `${CLAUDE_SKILL_DIR}` are Claude-only. Reference bundled files
  by path relative to the `SKILL.md`, and say so: "run `scripts/New-Image.ps1` from this skill's folder".
- Put executable logic in `scripts/`, in a language that runs on every OS the team uses
  (`pwsh` or `node`), rather than in shell snippets inside the markdown.

## Agent roles

Location: `.claude/agents/<name>.agent.md`, exposed to Copilot through `.github/agents`.

```markdown
---
name: reviewer
description: Reviews code changes and reports the single most important issue.
tools: Read, Grep, Glob
---

Provide the top 1 code review comment for the given code.
```

- `.agent.md` suffix is the Copilot convention; Claude Code reads any `.md` and uses `name`.
- Copilot deduplicates agents by file name without the suffix, so make the file stem equal `name`.
- `name` is required by Claude Code; `description` is required by Copilot. Always set both.
- `tools`: use a comma-separated string of Claude tool names. Copilot accepts them as aliases:
  `Bash` to `execute`, `Read` to `read`, `Edit`/`MultiEdit`/`Write`/`NotebookEdit` to `edit`,
  `Grep`/`Glob` to `search`, `Task` to `agent`, `WebFetch`/`WebSearch` to `web`, `TodoWrite` to `todo`.
  Unknown names are ignored. Omitting `tools` grants all tools in both.
- Omit `model`: model identifiers differ between products.
- Copilot-only fields (`target`, `mcp-servers`, `handoffs`, `argument-hint`, `user-invocable`,
  `disable-model-invocation`, `metadata`, `include-custom-instructions`) and Claude-only fields
  (for example `permissionMode`, `skills`, `hooks`) are ignored by the other side. Use them only
  for behavior that is allowed to differ.
- Copilot CLI subagents skip repository instructions unless `include-custom-instructions: true`.
- Keep the body under 30,000 characters (Copilot limit).

## Hooks

Hooks are the one element that cannot share a single config file: each harness has its own
event names, input shape and output shape. Share the **logic** and keep a thin config per harness.

**Logic: one script, `.claude/hooks/<name>.ps1`**, taking `-Harness claude|copilot|vscode`.

| Harness | Config file | Event key | Input on stdin | Deny output on stdout |
| --- | --- | --- | --- | --- |
| claude | `.claude/settings.json` | `PreToolUse` with `matcher` | `tool_name`, `tool_input` (object), `cwd`, `hook_event_name` | `{"hookSpecificOutput":{"hookEventName","permissionDecision":"deny","permissionDecisionReason"}}` |
| vscode | `.vscode/hooks/<name>.json` | `PreToolUse` | `tool_name`, `tool_input` | same as claude |
| cli, cloud | `.github/hooks/<name>.json` (`"version": 1`) | `preToolUse` (camelCase) | `toolName`, `toolArgs` (JSON **string**), `cwd` | `{"permissionDecision":"deny","permissionDecisionReason"}` |

Copilot switches to the VS Code-style payload for PascalCase event names, so read input leniently
(accept both field namings, parse `toolArgs` when it is a string) and pick the output style from `-Harness`.

**Exit codes**

| Exit | claude | cli, cloud (`preToolUse`) |
| --- | --- | --- |
| 0 | allow, stdout JSON parsed | allow, stdout JSON parsed |
| 2 | block, stderr shown to the model | deny, even if stdout says allow |
| 1 or other | non-blocking error, call proceeds | **deny** (fail-closed) |
| timeout | non-blocking | fail-open |

Script rules that follow from this:

- To deny: write exactly one JSON object to stdout, the reason to stderr, then `exit 2`.
  Exit 2 blocks everywhere even if a harness rejects the JSON.
- On any internal error: `exit 0` with no output (fail open). Never `exit 1`: Copilot would deny
  every tool call. For the same reason do not use `ValidateSet` on parameters; a binding failure exits 1.
- Copilot hook entries have no `matcher`, so the script must filter tool names itself. Tool names
  differ per harness (`Write`/`Edit` in claude, `create`/`edit`/`apply_patch` in cli,
  `create_file`/`replace_string_in_file` in vscode); match on a pattern, not a fixed list.
- Invoke with `pwsh -NoProfile -NonInteractive -File ...` so it runs on every OS.

**Configs**

Claude Code, `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -NonInteractive -File \"$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.ps1\" -Harness claude",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Copilot CLI and cloud agent, `.claude/hooks/<name>.json` (seen as `.github/hooks/<name>.json`):

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "pwsh -NoProfile -NonInteractive -File .claude/hooks/<name>.ps1 -Harness copilot",
        "powershell": "pwsh -NoProfile -NonInteractive -File .claude/hooks/<name>.ps1 -Harness copilot",
        "timeoutSec": 15
      }
    ]
  }
}
```

Set both `bash` and `powershell`: the cloud agent ignores `powershell` and runs `bash` on Linux,
so `pwsh` must be on its PATH there.

VS Code, `.vscode/hooks/<name>.json`, plus `.vscode/settings.json` to stop VS Code from also
loading the other two configs with the wrong payload shape:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "pwsh -NoProfile -NonInteractive -File .claude/hooks/<name>.ps1 -Harness vscode",
        "cwd": ".",
        "timeout": 15
      }
    ]
  }
}
```

```jsonc
{
  "chat.hookFilesLocations": {
    ".vscode/hooks": true,
    ".github/hooks": false,
    ".claude/settings.json": false
  },
  "chat.useClaudeHooks": false
}
```

`.gitignore` must let these through: `.vscode/*`, then `!.vscode/settings.json` and `!.vscode/hooks/`.

**Known trap: Copilot CLI runs the Claude config too.** Copilot CLI reads `hooks` from
`.claude/settings.json` in addition to `.github/hooks/`. The PascalCase event makes it use the
Claude-style payload, so `-Harness claude` output is still correct, but the hook can run twice
per tool call. Hooks must therefore be idempotent and cheap. How Copilot CLI applies the Claude
`matcher` to its own tool names is not documented; do not depend on it.

## MCP config

- One file: `.mcp.json` at the repository root, top-level key `mcpServers`. Claude Code, VS Code
  and Copilot CLI all read it. Do not add `.vscode/mcp.json` (deprecated, uses `servers`, and
  duplicates entries).
- Set `"type"` explicitly on every server: `"stdio"` (with `command`, `args`) or `"http"` (with `url`).
- Never inline secrets. Claude Code expands `${VAR}` and `${VAR:-default}` in `.mcp.json`. Whether
  VS Code and Copilot CLI expand the same syntax in `.mcp.json` is not documented; test before
  relying on it.
- OS portability: `"command": "cmd", "args": ["/c", "npx", ...]` is what Claude Code needs for
  `npx` on native Windows, but it fails on macOS, Linux and the cloud agent. If the team is mixed,
  prefer `http` servers or `docker`, or accept that `npx` stdio servers are per-OS.
- Pin package versions instead of `@latest` where you can; an unpinned server runs whatever was published last.
- Cloud agent does not read `.mcp.json`. Configure it on GitHub.com under repository
  Settings > Copilot > MCP servers (same `mcpServers` JSON shape), store secrets as Agents secrets
  prefixed `COPILOT_MCP_`, or declare `mcp-servers` in an agent's frontmatter. It supports tools
  only (no resources or prompts) and no OAuth remote servers. GitHub and Playwright servers are on by default.

## Checklist for a new element

1. Write it under `.claude/` (or `AGENTS.md`, `.mcp.json`) using the frontmatter subset above.
2. Instruction file: `.instructions.md` suffix, matching `paths` and `applyTo`.
3. Skill: folder name equals `name`, triggers inside `description`, body reads correctly without substitution.
4. Agent: `.agent.md` suffix, stem equals `name`, `description` set, `tools` as Claude names, no `model`.
5. Hook: logic in the shared script, one config entry per harness (three files), deny with exit 2, fail open with exit 0.
6. MCP server: added to `.mcp.json` with explicit `type`, and to GitHub repository settings if the cloud agent needs it.
7. Run the checks below.

## Checks

```bash
git ls-files -s .github                 # every entry should be mode 120000 (a symlink)
ls -la .github                          # each should point into ../.claude/
```

Test a hook by piping each harness's payload into the script:

```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"node_modules/x.js"},"cwd":"."}' \
  | pwsh -NoProfile -File .claude/hooks/<name>.ps1 -Harness claude; echo "exit $?"
echo '{"toolName":"edit","toolArgs":"{\"path\":\"node_modules/x.js\"}","cwd":"."}' \
  | pwsh -NoProfile -File .claude/hooks/<name>.ps1 -Harness copilot; echo "exit $?"
```

Expect exit 2 with one JSON object on stdout for a denied call, and exit 0 with no output otherwise.
