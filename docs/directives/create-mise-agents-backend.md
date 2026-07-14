---
type: Directive
title: create-mise-agents-backend
description: Create a mise backend plugin that versions five coding agents.
status: done
---

# Goal

Deliver a working `agents` backend plugin, based on `jdx/mise-backend-plugin-template` revision `8b8583a677235c7be3bcfc8ff047f3dec4687b2a`, that lets mise list, install, select, update, and uninstall reproducible versions of Codex, Claude Code, Kimi Code, Pi, and Cursor Agent.

# Architecture

- Map `codex`, `claude`, `kimi`, and `pi` to their official npm packages in one small shared table. Use npm itself for authoritative version lists and prefix-local installation, exposing `<install_path>/node_modules/.bin`.
- Treat `cursor` as the sole non-npm tool. Read its current immutable build identifier from Cursor's official installer, download the matching official OS/architecture archive, extract it under the mise install path, and expose both `cursor-agent` and `agent`. The upstream installer publishes only the current build; exact previously known pins remain constructible while Cursor retains their archives, but remote listing is current-only.
# Tech stack

- Lua 5.1-compatible mise/vfox backend hooks and mise-provided `cmd`, `http`, `json`, `file`, and `archiver` modules.
- Node.js 24 and npm for npm-backed tools.
- The template's mise, hk, LuaLS, StyLua, and actionlint configuration.

# Global constraints

- Support only `codex`, `claude`, `kimi`, `pi`, and `cursor`; reject unknown tool names, including `skills`, before network or shell work.
- Use upstream package/archive version strings unchanged and install only inside `ctx.install_path`.
- Do not manage skills, plugins, agent configuration, sessions, prompts, or credentials.
- Quote every shell-derived path/version passed to npm and validate version characters before command execution.
- Supported Cursor targets are Linux/macOS on x64/arm64, matching Cursor's official installer.

# Scope

- Copy the current official template's plugin/tooling files into the repository without its `.git` directory.
- Replace template placeholders and example hook bodies with the minimal backend implementation.
- Add one self-contained Lua hook test and a live mise smoke task.
- Document supported tools, prerequisites, usage, development checks, and Cursor platform limits.
- Preserve `docs/purpose.md` and `gnosis.toml`; add only this directive under `docs/directives/`.

# Implementation plan

### Task 1: Adopt and minimize the official template
**Load:** `/tmp/mise-backend-plugin-template` at `8b8583a677235c7be3bcfc8ff047f3dec4687b2a`; `gnosis://mise-agents/purpose.md`; `gnosis://core/procedures/development/implementing-directive.md`.
**Files:** create `.github/workflows/ci.yml`, `.luarc.json`, `LICENSE`, `README.md`, `hk.pkl`, `hooks/backend_exec_env.lua`, `hooks/backend_install.lua`, `hooks/backend_list_versions.lua`, `metadata.lua`, `mise-tasks/test`, `mise.toml`, `stylua.toml`, `types/mise-plugin.lua`.
**Interfaces:** preserve the template's `PLUGIN:BackendListVersions(ctx)`, `PLUGIN:BackendInstall(ctx)`, and `PLUGIN:BackendExecEnv(ctx)` hook signatures.

- [ ] Copy every non-`.git` template file, retain the template tooling/types, and replace metadata with backend name `agents`, version `0.1.0`, author `mise-agents contributors`, MIT license, and no invented homepage.
- [ ] Reduce README and hook files to implementation-relevant content; remove every `<BACKEND>`, `<GITHUB_USER>`, and `<TEST_TOOL>` placeholder.
- [ ] Add Node.js 24 to `mise.toml` because all npm-backed tools share it and Kimi requires Node 22.19 or newer.
- [ ] Run `rg '<BACKEND>|<GITHUB_USER>|<TEST_TOOL>' --glob '!docs/directives/**'`; expect no matches.
- [ ] Commit: `chore: adopt mise backend plugin template`.

### Task 2: Add a failing hook contract check
**Load:** `types/mise-plugin.lua`; the three hook files; `gnosis://core/procedures/development/implementing-directive.md#step-3---implementing-tasks`.
**Files:** create `tests/hooks.lua`; modify `mise.toml` test task only if needed.
**Interfaces:** test the public hook results and stub only mise-provided modules.

- [ ] Create `tests/hooks.lua` with plain Lua assertions that load each hook into a fresh `PLUGIN`, stub `cmd/http/json/file/archiver`, assert known/unknown tool routing, npm install prefix/version quoting, Cursor URL/platform/archive handling, and npm/Cursor PATH results.
- [ ] Run `lua tests/hooks.lua`; expect failure because the placeholder hooks do not satisfy the contract (red).
- [ ] Commit: `test: define agents backend contract`.

### Task 3: Implement version listing, installation, and environments
**Load:** `tests/hooks.lua`; `hooks/*.lua`; official npm metadata for `@openai/codex`, `@anthropic-ai/claude-code`, `@moonshot-ai/kimi-code`, and `@mariozechner/pi-coding-agent`; Cursor installer/archive observed 2026-07-13.
**Files:** modify `hooks/backend_list_versions.lua`, `hooks/backend_install.lua`, `hooks/backend_exec_env.lua`.
**Interfaces:** `BackendListVersions -> {versions=string[]}`; `BackendInstall -> {}`; `BackendExecEnv -> {env_vars={{key="PATH",value=string}}}`.

- [ ] In list versions, use a fixed npm package map and `npm view <package> versions --json`; decode the array, error on empty output, and return it unchanged. For Cursor, GET `https://cursor.com/install`, require status 200, extract the build ID from `downloads.cursor.com/lab/<build>/`, and return that single immutable build.
- [ ] In install, validate required fields and version characters, quote shell arguments, and use `npm install --ignore-scripts=false --prefix <install_path> <package>@<version>` for npm tools. For Cursor, map runtime OS/arch, download `https://downloads.cursor.com/lab/<version>/<os>/<arch>/agent-cli-package.tar.gz`, decompress under `install_path`, and symlink `dist-package/cursor-agent` to `dist-package/agent`.
- [ ] In exec env, return npm's `node_modules/.bin` for mapped tools and Cursor's `dist-package` for Cursor; reject unsupported names consistently.
- [ ] Run `lua tests/hooks.lua`; expect all assertions and the final success line (green).
- [ ] Run `stylua metadata.lua hooks/ tests/`; expect exit 0, then rerun `lua tests/hooks.lua`; expect green after refactor.
- [ ] Commit: `feat: manage agents with mise`.

### Task 4: Add live smoke coverage and documentation
**Load:** implemented hooks; template `mise-tasks/test`; current `README.md`.
**Files:** modify `mise-tasks/test`, `README.md`.
**Interfaces:** developer commands `mise run test`, `mise run lint`, and `mise run ci`; user syntax `agents:<tool>@<version>`.

- [ ] Make `mise run test` first run `lua tests/hooks.lua`, then use temporary `MISE_DATA_DIR`, `MISE_CACHE_DIR`, and `MISE_STATE_DIR` locations to link `agents` without changing the user's plugin/cache state, verify `mise ls-remote agents:pi` is non-empty, install `agents:pi@latest`, and run `mise exec agents:pi@latest -- pi --version`.
- [ ] Document installation/linking, five tool IDs, package/source mapping, examples, npm/Node prerequisites, Cursor target support and current-only remote listing, and development checks.
- [ ] Run `mise run test`; expect unit success, a non-empty Pi version list, successful installation, and version output.
- [ ] Commit: `docs: document agent workflows`.

### Task 5: Complete quality and scope verification
**Load:** repository diff from `05eb99c0361e1deaf02c4d2bb85237fd7e6acff1`; all directive acceptance criteria.
**Files:** modify only files already in scope for corrections; update this directive only for evidence/status.
**Interfaces:** full repository quality gate `mise run ci` and vault gate `gnosis validate`.

- [ ] Run `mise run ci`; expect hk checks and live tests to exit 0 on Linux/macOS-compatible code.
- [ ] Run `gnosis validate`; expect a valid vault.
- [ ] Run `git diff --check` and `git status --short`; expect no whitespace errors and only scoped files.
- [ ] Inspect the complete base-to-working-tree diff for correctness, security, YAGNI, source mapping, platform behavior, and every acceptance criterion; correct and reverify any blocking finding.
- [ ] Commit: `chore: verify mise agents backend`.

# Acceptance criteria

- The repository is recognizably based on the requested official template revision and contains no template placeholders — inspect copied tooling files and run `rg '<BACKEND>|<GITHUB_USER>|<TEST_TOOL>' --glob '!docs/directives/**'`; expect no matches.
- `agents:codex`, `agents:claude`, `agents:kimi`, and `agents:pi` list and install versions from their fixed official npm package mappings — run `lua tests/hooks.lua` and `mise ls-remote agents:pi`; expect green assertions and non-empty versions.
- `agents:cursor` resolves Cursor's current immutable build and constructs the official target-specific archive install without modifying the user's home directory — run `lua tests/hooks.lua`; expect Cursor version, URL, extraction, alias, and PATH assertions to pass.
- Unknown tools and unsafe versions fail before command/download execution — run `lua tests/hooks.lua`; expect rejection assertions with zero side effects.
- Documentation enables a new user to install all five managed agents without consulting source — inspect `README.md` for prerequisites, mapping, examples, and limitations.
- All repository and vault checks are clean — run `mise run ci`, `gnosis validate`, and `git diff --check`; expect exit 0.

# Completion evidence

- `mise run ci` passed full-file LuaLS, StyLua, actionlint, hook assertions, and an isolated live `agents:pi@0.73.1` install/execution on 2026-07-14.
- No skill or plugin management route or task remains.
- `gnosis validate`, `git diff --check`, and the placeholder scan passed on the completed tree.
