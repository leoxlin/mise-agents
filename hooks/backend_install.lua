--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    error("agents backend is not implemented: " .. tostring(ctx.tool))
end
