local M = {}

local function valid_identifier(value)
    return value ~= "" and value:match("^[0-9A-Za-z%-]+$") ~= nil
end

local function valid_number(value)
    return value:match("^%d+$") ~= nil and (value == "0" or value:sub(1, 1) ~= "0")
end

function M.parse_semver(tag)
    if type(tag) ~= "string" or tag == "" then
        return nil
    end

    local version = tag:gsub("^v", "")
    local without_build, build = version:match("^([^+]+)%+(.+)$")
    if without_build then
        version = without_build
        if build:find("%.%.") or build:sub(1, 1) == "." or build:sub(-1) == "." then
            return nil
        end
        for identifier in build:gmatch("[^.]+") do
            if not valid_identifier(identifier) then
                return nil
            end
        end
    elseif version:find("+", 1, true) then
        return nil
    end

    local core, prerelease = version:match("^([^-]+)%-(.+)$")
    if core then
        version = core
        if prerelease:find("%.%.") or prerelease:sub(1, 1) == "." or prerelease:sub(-1) == "." then
            return nil
        end
    elseif version:find("-", 1, true) then
        return nil
    end

    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major or not valid_number(major) or not valid_number(minor) or not valid_number(patch) then
        return nil
    end

    local parsed = { major = major, minor = minor, patch = patch, prerelease = {} }
    if prerelease then
        for identifier in prerelease:gmatch("[^.]+") do
            if not valid_identifier(identifier) or (identifier:match("^%d+$") and not valid_number(identifier)) then
                return nil
            end
            table.insert(parsed.prerelease, identifier)
        end
    end
    return parsed
end

local function compare_number(left, right)
    if #left ~= #right then
        return #left < #right and -1 or 1
    end
    if left == right then
        return 0
    end
    return left < right and -1 or 1
end

function M.compare_semver(left_tag, right_tag)
    local left = assert(M.parse_semver(left_tag))
    local right = assert(M.parse_semver(right_tag))
    for _, field in ipairs({ "major", "minor", "patch" }) do
        local result = compare_number(left[field], right[field])
        if result ~= 0 then
            return result
        end
    end

    local left_pre = left.prerelease
    local right_pre = right.prerelease
    if #left_pre == 0 or #right_pre == 0 then
        if #left_pre == #right_pre then
            return 0
        end
        return #left_pre == 0 and 1 or -1
    end

    for index = 1, math.max(#left_pre, #right_pre) do
        local left_id, right_id = left_pre[index], right_pre[index]
        if not left_id or not right_id then
            return left_id and 1 or -1
        end
        if left_id ~= right_id then
            local left_numeric = left_id:match("^%d+$") ~= nil
            local right_numeric = right_id:match("^%d+$") ~= nil
            if left_numeric and right_numeric then
                return compare_number(left_id, right_id)
            elseif left_numeric ~= right_numeric then
                return left_numeric and -1 or 1
            end
            return left_id < right_id and -1 or 1
        end
    end
    return 0
end

function M.validate_name(name)
    if
        type(name) ~= "string"
        or #name == 0
        or #name > 64
        or not name:match("^[a-z0-9][a-z0-9%-]*$")
        or name:sub(-1) == "-"
        or name:find("%-%-")
    then
        error("Invalid skill name: " .. tostring(name))
    end
    return name
end

local function valid_path(path)
    local wrapped = "/" .. path .. "/"
    return path ~= ""
        and not path:find("[%s%?#]")
        and not path:find("//", 1, true)
        and not wrapped:find("/%.?%./")
        and path:match("[^/]+%.git$") ~= nil
end

function M.normalize_source(options)
    local source = options and options.source
    if type(source) ~= "string" or source == "" then
        error("The source option is required")
    end

    local owner, repo = source:match("^([%w_.%-]+)/([%w_.%-]+)$")
    if owner and owner ~= "." and owner ~= ".." and repo ~= "." and repo ~= ".." then
        repo = repo:gsub("%.git$", "")
        if repo ~= "" then
            return "https://github.com/" .. owner .. "/" .. repo .. ".git"
        end
    end

    local github_owner, github_repo = source:match("^https://github%.com/([%w_.%-]+)/([%w_.%-]+)$")
    if github_owner and github_repo then
        github_repo = github_repo:gsub("%.git$", "")
        if github_repo ~= "" then
            return "https://github.com/" .. github_owner .. "/" .. github_repo .. ".git"
        end
    end

    local https_path = source:match("^https://[^/]+/(.+)$")
    local ssh_path = source:match("^ssh://[^/]+/(.+)$")
    local scp_path = source:match("^[%w_.%-]+@[%w_.%-]+:(.+)$")
    local path = https_path or ssh_path or scp_path
    if path and valid_path(path) then
        return source
    end

    error("Invalid source: expected GitHub owner/repo or a full HTTPS/SSH Git repository URL")
end

function M.shell_quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

function M.staged_path(ctx)
    return require("file").join_path(ctx.install_path, ".agents", "skills", M.validate_name(ctx.tool))
end

return M
