local common = dofile(RUNTIME.pluginDirPath .. "/lib.lua")

--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local skill = common.validate_name(ctx.tool)
    local source = common.normalize_source(ctx.options)
    if not common.parse_semver(ctx.version) then
        error("Invalid SemVer tag: " .. tostring(ctx.version))
    end
    if type(ctx.install_path) ~= "string" or ctx.install_path == "" then
        error("Install path cannot be empty")
    end

    local spec = source .. "#" .. ctx.version
    require("cmd").exec(
        "npx --yes skills add "
            .. common.shell_quote(spec)
            .. " --skill "
            .. common.shell_quote(skill)
            .. " --agent "
            .. common.shell_quote("universal")
            .. " --copy --yes",
        { cwd = ctx.install_path }
    )

    local skill_file = require("file").join_path(common.staged_path(ctx), "SKILL.md")
    if not require("file").exists(skill_file) then
        error("Skills CLI did not stage " .. skill_file)
    end
    return {}
end
