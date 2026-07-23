local common = dofile(RUNTIME.pluginDirPath .. "/lib.lua")

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    common.validate_name(ctx.tool)
    local source = common.normalize_source(ctx.options)
    local command = "git ls-remote --tags --refs " .. common.shell_quote(source)
    local ok, output = pcall(require("cmd").exec, command)
    if not ok then
        error("Failed to list Git tags for " .. source .. ": " .. tostring(output))
    end

    local versions, seen = {}, {}
    for tag in output:gmatch("refs/tags/([^\r\n]+)") do
        if common.parse_semver(tag) and not seen[tag] then
            seen[tag] = true
            table.insert(versions, tag)
        end
    end
    if #versions == 0 then
        error("No SemVer tags found for " .. source)
    end

    table.sort(versions, function(left, right)
        local compared = common.compare_semver(left, right)
        return compared == 0 and left < right or compared < 0
    end)
    return { versions = versions }
end
