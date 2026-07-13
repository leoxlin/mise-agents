local npm_tools = {
    codex = true,
    claude = true,
    kimi = true,
    pi = true,
    skills = true,
}

--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    local bin_path
    if npm_tools[ctx.tool] then
        bin_path = file.join_path(ctx.install_path, "node_modules", ".bin")
    elseif ctx.tool == "cursor" then
        bin_path = file.join_path(ctx.install_path, "dist-package")
    else
        error("Unsupported tool: " .. tostring(ctx.tool))
    end

    return { env_vars = { { key = "PATH", value = bin_path } } }
end
