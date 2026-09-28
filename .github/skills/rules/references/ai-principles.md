# AI Working Principles

## Core Rules

The four rules are maintained in [Rules Core](core.md). The notes below clarify their
application without keeping a second copy of the checklist.

## Detailed Guidance

### 1. Use current evidence

- Start from a concrete file, symbol, error, or behavior and inspect the current code path that owns it.
- Consult authoritative, up-to-date documentation when behavior depends on an API, tool, or version.
- Read the complete owning section or implementation, including constraints and exceptions, before drawing a conclusion from a search result.

### 2. Deliver simply and stay in scope

- Check existing helpers before adding a wrapper, subclass, override, or fallback path.
- Leave optional infrastructure and extension points out of a fix unless the requested behavior needs them.
- Prefer the current terminal/tool session and supported quiet or no-window options. Do not spawn
	separate consoles or GUI windows for routine script work.
- Keep logs accessible without automatically revealing terminal panels or stealing focus where the
	host supports it. Bring UI forward only when explicitly requested or needed for user action.
- If a required command has no verified no-window option, try an approved non-GUI alternative first.
	Otherwise explain the limitation and wait for permission before opening a window. Reuse explicit
	approval for that visible action; no answer leaves the command pending, including unattended runs.
- Await one-shot scripts and retain exit status, output, and errors. Run long-lived services/watchers
	in the background with retrievable status and logs; do not leave required work unverified.
- Explain before opening UI for authentication, consent, or manual input. Never auto-approve,
	bypass denials, hide a needed prompt, or request secrets through chat.

### 3. Do not overdefend

- Do not repeatedly handle states already excluded by established invariants.
- Add hashing, SHA-256, signatures, or similar mechanisms only for concrete security, integrity, or interoperability requirements.

### 4. Verify proportionately

- A local fix starts with its focused regression check; a shared behavior change also needs checks for affected consumers.