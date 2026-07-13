local packages = {
    codex = "@openai/codex",
    claude = "@anthropic-ai/claude-code",
    kimi = "@moonshot-ai/kimi-code",
    pi = "@mariozechner/pi-coding-agent",
    skills = "skills",
}

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function cursor_target()
    local os_name = RUNTIME.osType:lower()
    if os_name == "macos" then
        os_name = "darwin"
    end
    if os_name ~= "darwin" and os_name ~= "linux" then
        error("Unsupported Cursor operating system: " .. RUNTIME.osType)
    end

    local arch = RUNTIME.archType:lower()
    if arch == "amd64" or arch == "x86_64" then
        arch = "x64"
    elseif arch == "aarch64" then
        arch = "arm64"
    end
    if arch ~= "x64" and arch ~= "arm64" then
        error("Unsupported Cursor architecture: " .. RUNTIME.archType)
    end
    return os_name, arch
end

--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local package = packages[ctx.tool]
    if not package and ctx.tool ~= "cursor" then
        error("Unsupported tool: " .. tostring(ctx.tool))
    end
    if not ctx.version or ctx.version == "" or not ctx.version:match("^[%w%.%+%-]+$") then
        error("Invalid version: " .. tostring(ctx.version))
    end
    if not ctx.install_path or ctx.install_path == "" then
        error("Install path cannot be empty")
    end

    if package then
        local spec = package .. "@" .. ctx.version
        require("cmd").exec(
            "npm install --ignore-scripts=false --no-audit --no-fund --prefix "
                .. shell_quote(ctx.install_path)
                .. " "
                .. shell_quote(spec)
        )
        return {}
    end

    local os_name, arch = cursor_target()
    local file = require("file")
    local archive = file.join_path(ctx.install_path, "cursor-agent.tar.gz")
    local url = "https://downloads.cursor.com/lab/"
        .. ctx.version
        .. "/"
        .. os_name
        .. "/"
        .. arch
        .. "/agent-cli-package.tar.gz"

    require("cmd").exec("mkdir -p " .. shell_quote(ctx.install_path))
    require("http").download_file({ url = url }, archive)
    require("archiver").decompress(archive, ctx.install_path)
    os.remove(archive)
    file.symlink(
        file.join_path(ctx.install_path, "dist-package", "cursor-agent"),
        file.join_path(ctx.install_path, "dist-package", "agent")
    )
    return {}
end
