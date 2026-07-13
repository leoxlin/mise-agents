--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    error("agents backend is not implemented: " .. tostring(ctx.tool))
end
