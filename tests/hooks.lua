local calls = {
    commands = {},
    gets = {},
    downloads = {},
    decompress = {},
    symlinks = {},
}

package.preload.cmd = function()
    return {
        exec = function(command)
            table.insert(calls.commands, command)
            return '["1.0.0","2.0.0"]'
        end,
    }
end

package.preload.json = function()
    return {
        decode = function(value)
            assert(value == '["1.0.0","2.0.0"]')
            return { "1.0.0", "2.0.0" }
        end,
    }
end

package.preload.http = function()
    return {
        get = function(opts)
            table.insert(calls.gets, opts.url)
            return {
                status_code = 200,
                body = "https://downloads.cursor.com/lab/2026.07.09-a3815c0/linux/x64/agent-cli-package.tar.gz",
            }
        end,
        download_file = function(opts, path)
            table.insert(calls.downloads, { url = opts.url, path = path })
        end,
    }
end

package.preload.file = function()
    return {
        join_path = function(...)
            return table.concat({ ... }, "/")
        end,
        symlink = function(src, dst)
            table.insert(calls.symlinks, { src = src, dst = dst })
        end,
    }
end

package.preload.archiver = function()
    return {
        decompress = function(archive, dest)
            table.insert(calls.decompress, { archive = archive, dest = dest })
        end,
    }
end

RUNTIME = { osType = "Linux", archType = "amd64" }

local function load_hook(path)
    PLUGIN = {}
    dofile(path)
    return PLUGIN
end

local function expect_error(fn, pattern)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error")
    assert(tostring(err):match(pattern), tostring(err))
end

local list = load_hook("hooks/backend_list_versions.lua")
for tool, package in pairs({
    codex = "@openai/codex",
    claude = "@anthropic-ai/claude-code",
    kimi = "@moonshot-ai/kimi-code",
    pi = "@mariozechner/pi-coding-agent",
}) do
    assert(#list:BackendListVersions({ tool = tool }).versions == 2)
    assert(calls.commands[#calls.commands]:find(package, 1, true))
end

expect_error(function()
    list:BackendListVersions({ tool = "skills" })
end, "Unsupported tool")

local cursor_versions = list:BackendListVersions({ tool = "cursor" }).versions
assert(cursor_versions[1] == "2026.07.09-a3815c0")
assert(calls.gets[1] == "https://cursor.com/install")

local before = #calls.commands + #calls.gets
expect_error(function()
    list:BackendListVersions({ tool = "other" })
end, "Unsupported tool")
assert(#calls.commands + #calls.gets == before)

local install = load_hook("hooks/backend_install.lua")
install:BackendInstall({ tool = "codex", version = "1.2.3", install_path = "/tmp/agent path" })
assert(calls.commands[#calls.commands]:match("npm install"))
assert(calls.commands[#calls.commands]:match("@openai/codex@1%.2%.3"))
assert(calls.commands[#calls.commands]:match("'/tmp/agent path'"))

before = #calls.commands
expect_error(function()
    install:BackendInstall({ tool = "codex", version = "1.0;touch nope", install_path = "/tmp/agent" })
end, "Invalid version")
assert(#calls.commands == before)
expect_error(function()
    install:BackendInstall({ tool = "other", version = "1.0.0", install_path = "/tmp/agent" })
end, "Unsupported tool")
assert(#calls.commands == before)

install:BackendInstall({ tool = "cursor", version = "2026.07.09-a3815c0", install_path = "/tmp/cursor" })
assert(
    calls.downloads[1].url == "https://downloads.cursor.com/lab/2026.07.09-a3815c0/linux/x64/agent-cli-package.tar.gz"
)
assert(calls.downloads[1].path == "/tmp/cursor/cursor-agent.tar.gz")
assert(calls.decompress[1].archive == calls.downloads[1].path)
assert(calls.decompress[1].dest == "/tmp/cursor")
assert(calls.symlinks[1].src == "/tmp/cursor/dist-package/cursor-agent")
assert(calls.symlinks[1].dst == "/tmp/cursor/dist-package/agent")

RUNTIME = { osType = "macOS", archType = "arm64" }
install:BackendInstall({ tool = "cursor", version = "2026.07.09-a3815c0", install_path = "/tmp/cursor-mac" })
assert(
    calls.downloads[2].url
        == "https://downloads.cursor.com/lab/2026.07.09-a3815c0/darwin/arm64/agent-cli-package.tar.gz"
)
RUNTIME = { osType = "Windows", archType = "amd64" }
before = #calls.commands
expect_error(function()
    install:BackendInstall({ tool = "cursor", version = "2026.07.09-a3815c0", install_path = "/tmp/cursor" })
end, "Unsupported Cursor operating system")
assert(#calls.commands == before)

local env = load_hook("hooks/backend_exec_env.lua")
assert(
    env:BackendExecEnv({ tool = "pi", version = "1.0.0", install_path = "/tmp/pi" }).env_vars[1].value
        == "/tmp/pi/node_modules/.bin"
)
assert(
    env:BackendExecEnv({ tool = "cursor", version = "1.0.0", install_path = "/tmp/cursor" }).env_vars[1].value
        == "/tmp/cursor/dist-package"
)
expect_error(function()
    env:BackendExecEnv({ tool = "other", version = "1.0.0", install_path = "/tmp/other" })
end, "Unsupported tool")
expect_error(function()
    env:BackendExecEnv({ tool = "skills", version = "1.0.0", install_path = "/tmp/skills" })
end, "Unsupported tool")

print("hooks: ok")
