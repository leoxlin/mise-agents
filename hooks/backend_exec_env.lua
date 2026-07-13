--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    error("agents backend is not implemented: " .. tostring(ctx.tool))
end
