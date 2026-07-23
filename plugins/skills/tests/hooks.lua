local root = assert(os.getenv("PWD"))
RUNTIME = { pluginDirPath = root, osType = "Linux", archType = "amd64" }

local common = dofile("lib.lua")

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function run(command, options)
    if options and options.cwd then
        command = "cd " .. shell_quote(options.cwd) .. " && " .. command
    end
    local pipe = assert(io.popen(command .. " 2>&1"))
    local output = pipe:read("*a")
    local ok = pipe:close()
    if not ok then
        error(output)
    end
    return output
end

local actual_cmd = { exec = run }
local symlink_calls = {}
local actual_file = {
    join_path = function(...)
        local path = table.concat({ ... }, "/"):gsub("/+", "/")
        return path
    end,
    exists = function(path)
        local handle = io.open(path, "r")
        if handle then
            handle:close()
            return true
        end
        return false
    end,
    symlink = function(source, destination)
        table.insert(symlink_calls, { source = source, destination = destination })
        run("ln -s " .. shell_quote(source) .. " " .. shell_quote(destination))
    end,
}

package.preload.file = function()
    return actual_file
end

local function load_hook(path)
    PLUGIN = {}
    dofile(path)
    return PLUGIN
end

local function expect_error(fn, pattern)
    local ok, err = pcall(fn)
    assert(not ok, "expected an error")
    assert(tostring(err):match(pattern), tostring(err))
end

local function assert_equal(actual, expected)
    assert(actual == expected, ("expected %q, got %q"):format(tostring(expected), tostring(actual)))
end

for _, valid in ipairs({ "a", "find-skills", "skill-2", string.rep("a", 64) }) do
    assert_equal(common.validate_name(valid), valid)
end
for _, invalid in ipairs({ "", "-bad", "bad-", "Bad", "bad_name", "bad--name", string.rep("a", 65) }) do
    expect_error(function()
        common.validate_name(invalid)
    end, "Invalid skill name")
end

assert_equal(common.normalize_source({ source = "vercel-labs/skills" }), "https://github.com/vercel-labs/skills.git")
assert_equal(
    common.normalize_source({ source = "https://github.com/vercel-labs/skills" }),
    "https://github.com/vercel-labs/skills.git"
)
for _, source in ipairs({
    "https://gitlab.example.com/group/project.git",
    "ssh://git@gitlab.example.com/group/project.git",
    "git@gitlab.example.com:group/project.git",
}) do
    assert_equal(common.normalize_source({ source = source }), source)
end
for _, source in ipairs({
    "",
    ".",
    "../skill",
    "/tmp/skill",
    "https://github.com/owner/repo/tree/main",
    "https://example.com/repo.git#v1.0.0",
    "https://example.com/repo.git/subdir",
    "https://example.com/../repo.git",
    "https://github.com/owner/.git",
}) do
    expect_error(function()
        common.normalize_source({ source = source })
    end, source == "" and "source option is required" or "Invalid source")
end

for _, valid in ipairs({
    "0.0.0",
    "v1.2.3",
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0+build.7",
    "v2.0.0-rc.1+sha.abc",
}) do
    assert(common.parse_semver(valid), valid)
end
for _, invalid in ipairs({
    "1",
    "1.2",
    "01.2.3",
    "1.02.3",
    "1.2.03",
    "1.0.0-01",
    "1.0.0-alpha..1",
    "1.0.0+",
    "release-1.0.0",
}) do
    assert(not common.parse_semver(invalid), invalid)
end

local commands = {}
package.loaded.cmd = {
    exec = function(command)
        table.insert(commands, command)
        return table.concat({
            "a\trefs/tags/v2.0.0",
            "b\trefs/tags/v1.0.0",
            "c\trefs/tags/v1.0.0-alpha.10",
            "d\trefs/tags/v1.0.0-alpha.2",
            "e\trefs/tags/not-semver",
            "f\trefs/tags/v1.0.0",
            "g\trefs/tags/v1.0.0+build.2",
            "h\trefs/tags/v1.0.0+build.1",
        }, "\n")
    end,
}
local list = load_hook("hooks/backend_list_versions.lua")
local versions = list:BackendListVersions({
    tool = "find-skills",
    options = { source = "vercel-labs/skills" },
}).versions
assert_equal(table.concat(versions, ","), "v1.0.0-alpha.2,v1.0.0-alpha.10,v1.0.0,v1.0.0+build.1,v1.0.0+build.2,v2.0.0")
assert_equal(commands[1], "git ls-remote --tags --refs 'https://github.com/vercel-labs/skills.git'")

package.loaded.cmd = {
    exec = function()
        return "a\trefs/tags/latest\n"
    end,
}
expect_error(function()
    list:BackendListVersions({ tool = "find-skills", options = { source = "owner/repo" } })
end, "No SemVer tags")
package.loaded.cmd = {
    exec = function()
        error("authentication failed")
    end,
}
expect_error(function()
    list:BackendListVersions({ tool = "find-skills", options = { source = "owner/repo" } })
end, "Failed to list Git tags")

local tmp = os.tmpname()
os.remove(tmp)
run("mkdir -p " .. shell_quote(tmp .. "/.agents/skills/find-skills"))
local skill_file = assert(io.open(tmp .. "/.agents/skills/find-skills/SKILL.md", "w"))
skill_file:write("---\nname: find-skills\n---\n")
skill_file:close()

commands = {}
package.loaded.cmd = {
    exec = function(command, options)
        table.insert(commands, { command = command, options = options })
        return ""
    end,
}
local install = load_hook("hooks/backend_install.lua")
install:BackendInstall({
    tool = "find-skills",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "vercel-labs/skills" },
})
assert_equal(
    commands[1].command,
    "npx --yes skills add 'https://github.com/vercel-labs/skills.git#v1.0.0' --skill 'find-skills' --agent 'universal' --copy --yes"
)
assert_equal(commands[1].options.cwd, tmp)
expect_error(function()
    install:BackendInstall({
        tool = "find-skills",
        version = "main",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "Invalid SemVer tag")
run("rm -f " .. shell_quote(tmp .. "/.agents/skills/find-skills/SKILL.md"))
expect_error(function()
    install:BackendInstall({
        tool = "find-skills",
        version = "v1.0.0",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "did not stage")

skill_file = assert(io.open(tmp .. "/.agents/skills/find-skills/SKILL.md", "w"))
skill_file:write("---\nname: find-skills\n---\n")
skill_file:close()
local home = tmp .. "/home"
local codex_home = tmp .. "/codex"
local claude_home = tmp .. "/claude"
local cache_root = tmp .. "/cache"
local cache_bucket = tmp:match("/([^/]+)/[^/]+$")
local stale_cache = cache_root .. "/" .. cache_bucket .. "/v0.9.0/exec_env_test.msgpack.z"
run("mkdir -p " .. shell_quote(stale_cache:match("^(.*)/[^/]+$")))
local cache_file = assert(io.open(stale_cache, "w"))
cache_file:write("stale")
cache_file:close()
package.loaded.cmd = {
    exec = function(command, options)
        if command == "mise cache path" then
            return cache_root .. "\n"
        end
        return actual_cmd.exec(command, options)
    end,
}
test_env = { HOME = home, CODEX_HOME = codex_home, CLAUDE_CONFIG_DIR = claude_home }
local original_getenv = os.getenv
os.getenv = function(name)
    return test_env[name]
end
run("mkdir -p " .. shell_quote(codex_home .. "/skills"))
run(
    "ln -s "
        .. shell_quote(tmp .. "/.agents/skills/find-skills")
        .. " "
        .. shell_quote(codex_home .. "/skills/find-skills")
)
run("mkdir -p " .. shell_quote(home .. "/.agents/skills/find-skills"))
local sentinel = assert(io.open(home .. "/.agents/skills/find-skills/sentinel", "w"))
sentinel:write("keep")
sentinel:close()
run("mkdir -p " .. shell_quote(home .. "/.cursor/skills"))
run("ln -s " .. shell_quote(tmp .. "/missing") .. " " .. shell_quote(home .. "/.cursor/skills/find-skills"))

local env_hook = load_hook("hooks/backend_exec_env.lua")
expect_error(function()
    env_hook:BackendExecEnv({
        tool = "find-skills",
        version = "v1.0.0",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "Refusing to replace non%-symlink")
assert(actual_file.exists(home .. "/.agents/skills/find-skills/sentinel"))
assert(not actual_file.exists(claude_home .. "/skills/find-skills"))
assert_equal(
    run("readlink " .. shell_quote(codex_home .. "/skills/find-skills")):gsub("%s+$", ""),
    tmp .. "/.agents/skills/find-skills"
)

run("rm -rf " .. shell_quote(home .. "/.agents/skills/find-skills"))
symlink_calls = {}
local result = env_hook:BackendExecEnv({
    tool = "find-skills",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "owner/repo" },
})
assert_equal(#result.env_vars, 0)
assert_equal(#symlink_calls, 4)
assert(not actual_file.exists(stale_cache))
for _, destination in ipairs({
    codex_home .. "/skills/find-skills",
    claude_home .. "/skills/find-skills",
    home .. "/.agents/skills/find-skills",
    home .. "/.pi/agent/skills/find-skills",
    home .. "/.cursor/skills/find-skills",
}) do
    assert_equal(run("readlink " .. shell_quote(destination)):gsub("%s+$", ""), tmp .. "/.agents/skills/find-skills")
end

local default_home = tmp .. "/default-home"
test_env = { HOME = default_home }
symlink_calls = {}
env_hook:BackendExecEnv({
    tool = "find-skills",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "owner/repo" },
})
assert_equal(#symlink_calls, 5)
for _, destination in ipairs({
    default_home .. "/.codex/skills/find-skills",
    default_home .. "/.claude/skills/find-skills",
    default_home .. "/.agents/skills/find-skills",
    default_home .. "/.pi/agent/skills/find-skills",
    default_home .. "/.cursor/skills/find-skills",
}) do
    assert_equal(run("readlink " .. shell_quote(destination)):gsub("%s+$", ""), tmp .. "/.agents/skills/find-skills")
end

expect_error(function()
    env_hook:BackendExecEnv({
        tool = "find-skills",
        version = "v1.0.0",
        install_path = tmp .. "/missing-install",
        options = { source = "owner/repo" },
    })
end, "Staged skill is missing")

os.getenv = original_getenv
run("rm -rf " .. shell_quote(tmp))
print("hooks: ok")
