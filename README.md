# mise-agents

A [mise backend plugin](https://mise.jdx.dev/backend-plugin-development.html) for reproducible coding-agent and skill tooling.

## Supported tools

| mise tool | Upstream package/source | Commands |
| --- | --- | --- |
| `agents:codex` | `@openai/codex` | `codex` |
| `agents:claude` | `@anthropic-ai/claude-code` | `claude` |
| `agents:kimi` | `@moonshot-ai/kimi-code` | `kimi` |
| `agents:pi` | `@mariozechner/pi-coding-agent` | `pi` |
| `agents:cursor` | Cursor's official Agent archive | `agent`, `cursor-agent` |

The npm-backed tools require Node.js and npm. Kimi currently requires Node.js 22.19 or newer; Node.js 24 is the development and CI version used here. Cursor supports Linux and macOS on x64 and arm64.

Cursor's installer exposes only its current immutable build, so `mise ls-remote agents:cursor` returns one version. Previously known exact versions remain installable while Cursor retains their archives.

## Install and use

Link a checkout for local use:

```sh
mise plugin link --force agents /path/to/mise-agents
mise use -g node@24
```

Then manage tools with normal mise commands:

```sh
mise ls-remote agents:codex
mise install agents:codex@latest
mise use agents:codex@latest
mise exec agents:codex@latest -- codex --version
mise upgrade agents:codex
mise uninstall agents:codex@0.144.3
```

The same `agents:<tool>@<version>` form works for every tool in the table.

## Skills

Skills themselves are managed by the [Skills CLI](https://github.com/vercel-labs/skills); this plugin does not install or version that CLI. From a local skill repository, run:

```sh
npx skills add .
```

The repository-local mise task runs the same command:

```sh
mise run skills:add
```

The task hands the current directory to `npx skills`; it does not author, host, or reinterpret skill content.

## Development

The repository is based on [`jdx/mise-backend-plugin-template`](https://github.com/jdx/mise-backend-plugin-template).

```sh
mise install
mise run test
mise run lint
mise run ci
```

The live smoke test uses temporary mise data, cache, and state directories, so it does not replace locally installed plugins.
