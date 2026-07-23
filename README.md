# mise-agents

A monorepo of [mise backend plugins](https://mise.jdx.dev/backend-plugin-development.html) for reproducible coding
agents and versioned [Agent Skills](https://agentskills.io/).

## Configure

Install either or both plugins directly from their repository subdirectories:

```toml
[plugins]
"vfox:agents" = "git::https://github.com/leoxlin/mise-agents.git//plugins/agents"
"vfox:skills" = "git::https://github.com/leoxlin/mise-agents.git//plugins/skills"

[tools]
node = "24"
"agents:pi" = "latest"
"skills:ponytail" = {
  version = "v4.8.4",
  source = "DietrichGebert/ponytail",
}
```

Both plugins require Node.js and npm. The skills plugin also requires `git` and supports Linux and macOS.
The explicit `vfox:` keys are required for `git::` plugin sources on mise 2026.6.14.

## Agents plugin

The `agents` plugin manages these tools:

| mise tool | Upstream package/source | Commands |
| --- | --- | --- |
| `agents:codex` | `@openai/codex` | `codex` |
| `agents:claude` | `@anthropic-ai/claude-code` | `claude` |
| `agents:kimi` | `@moonshot-ai/kimi-code` | `kimi` |
| `agents:pi` | `@earendil-works/pi-coding-agent` | `pi` |
| `agents:cursor` | Cursor's official Agent archive | `agent`, `cursor-agent` |

Kimi and Pi require Node.js 22.19 or newer; Node.js 24 is used for development and CI. Cursor supports Linux and
macOS on x64 and arm64. Its installer exposes only the current immutable build, so `mise ls-remote agents:cursor`
returns one version. Previously known exact versions remain installable while Cursor retains their archives.

Use normal mise commands for every agent:

```sh
mise ls-remote agents:codex
mise install agents:codex@latest
mise use agents:codex@latest
mise exec agents:codex@latest -- codex --version
mise upgrade agents:codex
mise uninstall agents:codex@0.144.3
```

## Skills plugin

Each `skills:<name>` tool stages one canonical skill copy, then links it into Codex, Claude Code, Kimi Code, Pi, and
Cursor. The plugin adds no executable or PATH entry.

The required `source` option accepts GitHub `owner/repo` shorthand or a full HTTPS/SSH Git repository URL. Local
paths, URL fragments or embedded refs, and repository subpaths are rejected. Private repositories use the Git
credentials already available to `git` and `npx`; the plugin does not store credentials.

Skill names must be 1–64 lowercase letters, digits, or internal single hyphens. Available versions are exact
repository tags conforming to SemVer 2.0, with an optional `v` prefix. Non-SemVer tags are ignored.

```sh
mise ls-remote skills:ponytail
mise install skills:ponytail@v4.8.4
mise use skills:ponytail@v4.8.4
mise upgrade skills:ponytail
```

If `source` changes while the selected version stays the same, force a reinstall because mise keys installations by
skill name and version:

```sh
mise uninstall skills:ponytail@v4.8.4
mise install skills:ponytail@v4.8.4
```

### Activation and lifecycle

Every activation maintains these user-global links:

| Agent | Destination |
| --- | --- |
| Codex | `${CODEX_HOME:-$HOME/.codex}/skills/<skill>` |
| Claude Code | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/<skill>` |
| Kimi Code | `$HOME/.agents/skills/<skill>` |
| Pi | `$HOME/.pi/agent/skills/<skill>` |
| Cursor | `$HOME/.cursor/skills/<skill>` |

An existing or broken symlink is replaced. A real file or directory at any destination aborts activation before any
destination changes. All five destinations are maintained whether or not their agents are installed.

Activation is user-global: when concurrent projects select different versions of the same skill, the most recently
evaluated mise environment wins. Mise has no backend deactivate/uninstall hook, so `mise unuse` can leave valid links
and `mise uninstall` can leave broken links. To unlink a skill manually:

```sh
skill=ponytail
test ! -L "${CODEX_HOME:-$HOME/.codex}/skills/${skill}" || rm "${CODEX_HOME:-$HOME/.codex}/skills/${skill}"
test ! -L "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/${skill}" || rm "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/${skill}"
test ! -L "$HOME/.agents/skills/${skill}" || rm "$HOME/.agents/skills/${skill}"
test ! -L "$HOME/.pi/agent/skills/${skill}" || rm "$HOME/.pi/agent/skills/${skill}"
test ! -L "$HOME/.cursor/skills/${skill}" || rm "$HOME/.cursor/skills/${skill}"
```

Installing a skill runs the current Skills CLI through `npx` and copies content from the selected Git tag. Review
and trust both the repository/tag and the CLI before installation. Treat activated skills as executable supply-chain
inputs because their instructions and bundled files become available to every supported agent.

## Development

The plugins are based on [`jdx/mise-backend-plugin-template`](https://github.com/jdx/mise-backend-plugin-template).

```sh
mise plugin link --force agents "$PWD/plugins/agents"
mise plugin link --force skills "$PWD/plugins/skills"
mise install
mise run test
mise run lint
mise run ci
```

The live smoke test isolates HOME plus mise data, cache, and state. It installs fixed Pi and Ponytail versions,
verifies skill switching across all five destinations, and proves collision preflight preserves an existing
directory.
