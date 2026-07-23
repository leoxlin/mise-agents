local common = dofile(RUNTIME.pluginDirPath .. "/lib.lua")

local function getenv(name)
    local value = os.getenv(name)
    return value ~= "" and value or nil
end

local function inspect_link(path)
    local quote = common.shell_quote(path)
    local output = require("cmd").exec(
        "if [ -L "
            .. quote
            .. " ]; then printf 'link\\n'; readlink "
            .. quote
            .. "; elif [ -e "
            .. quote
            .. " ]; then printf 'collision\\n'; else printf 'missing\\n'; fi"
    )
    local state, target = output:match("^([^\r\n]+)[\r\n]*(.-)[\r\n]*$")
    return state, target
end

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    local source = common.staged_path(ctx)
    if not file.exists(file.join_path(source, "SKILL.md")) then
        error("Staged skill is missing: " .. source)
    end

    local home = getenv("HOME")
    if not home then
        error("HOME is required")
    end
    local destinations = {
        file.join_path(getenv("CODEX_HOME") or file.join_path(home, ".codex"), "skills", ctx.tool),
        file.join_path(getenv("CLAUDE_CONFIG_DIR") or file.join_path(home, ".claude"), "skills", ctx.tool),
        file.join_path(home, ".agents", "skills", ctx.tool),
        file.join_path(home, ".pi", "agent", "skills", ctx.tool),
        file.join_path(home, ".cursor", "skills", ctx.tool),
    }

    local states = {}
    for index, destination in ipairs(destinations) do
        local state, target = inspect_link(destination)
        if state == "collision" then
            error("Refusing to replace non-symlink skill destination: " .. destination)
        end
        states[index] = state == "link" and target == source
    end

    for index, destination in ipairs(destinations) do
        if not states[index] then
            local parent = destination:match("^(.*)/[^/]+$")
            require("cmd").exec("mkdir -p " .. common.shell_quote(parent))
            os.remove(destination)
            file.symlink(source, destination)
        end
    end
    -- mise caches BackendExecEnv by install-directory mtime; a future mtime keeps activation side effects live.
    local tomorrow = os.date("%Y%m%d%H%M.%S", os.time() + 86400)
    require("cmd").exec("touch -t " .. tomorrow .. " " .. common.shell_quote(ctx.install_path))
    return { env_vars = {} }
end
