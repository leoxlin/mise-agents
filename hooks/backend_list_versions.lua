local packages = {
    codex = "@openai/codex",
    claude = "@anthropic-ai/claude-code",
    kimi = "@moonshot-ai/kimi-code",
    pi = "@mariozechner/pi-coding-agent",
}

--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    local package = packages[ctx.tool]
    if package then
        local output = require("cmd").exec("npm view " .. package .. " versions --json")
        local versions = require("json").decode(output)
        if type(versions) ~= "table" or #versions == 0 then
            error("No versions found for " .. ctx.tool)
        end
        return { versions = versions }
    end

    if ctx.tool == "cursor" then
        local response, err = require("http").get({ url = "https://cursor.com/install" })
        if err or not response or response.status_code ~= 200 then
            error("Failed to fetch Cursor installer" .. (err and ": " .. tostring(err) or ""))
        end

        local version = response.body:match("downloads%.cursor%.com/lab/([^/]+)/")
        if not version then
            error("Cursor installer did not contain a versioned download")
        end
        return { versions = { version } }
    end

    error("Unsupported tool: " .. tostring(ctx.tool))
end
