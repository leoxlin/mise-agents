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

for _, valid in ipairs({ "a", "ponytail", "skill-2", string.rep("a", 64) }) do
    assert_equal(common.validate_name(valid), valid)
end
for _, invalid in ipairs({ "", "-bad", "bad-", "Bad", "bad_name", "bad--name", string.rep("a", 65) }) do
    expect_error(function()
        common.validate_name(invalid)
    end, "Invalid skill name")
end

assert_equal(
    common.normalize_source({ source = "DietrichGebert/ponytail" }),
    "https://github.com/DietrichGebert/ponytail.git"
)
assert_equal(
    common.normalize_source({ source = "https://github.com/DietrichGebert/ponytail" }),
    "https://github.com/DietrichGebert/ponytail.git"
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
    tool = "ponytail",
    options = { source = "DietrichGebert/ponytail" },
}).versions
assert_equal(table.concat(versions, ","), "v1.0.0-alpha.2,v1.0.0-alpha.10,v1.0.0,v1.0.0+build.1,v1.0.0+build.2,v2.0.0")
assert_equal(commands[1], "git ls-remote --tags --refs 'https://github.com/DietrichGebert/ponytail.git'")

package.loaded.cmd = {
    exec = function()
        return "a\trefs/tags/latest\n"
    end,
}
expect_error(function()
    list:BackendListVersions({ tool = "ponytail", options = { source = "owner/repo" } })
end, "No SemVer tags")
package.loaded.cmd = {
    exec = function()
        error("authentication failed")
    end,
}
expect_error(function()
    list:BackendListVersions({ tool = "ponytail", options = { source = "owner/repo" } })
end, "Failed to list Git tags")

local tmp = os.tmpname()
os.remove(tmp)
run("mkdir -p " .. shell_quote(tmp .. "/.agents/skills/ponytail"))
local skill_file = assert(io.open(tmp .. "/.agents/skills/ponytail/SKILL.md", "w"))
skill_file:write("---\nname: ponytail\n---\n")
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
    tool = "ponytail",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "DietrichGebert/ponytail" },
})
assert_equal(
    commands[1].command,
    "npx --yes skills add 'https://github.com/DietrichGebert/ponytail.git#v1.0.0' --skill 'ponytail' --agent 'universal' --copy --yes"
)
assert_equal(commands[1].options.cwd, tmp)
expect_error(function()
    install:BackendInstall({
        tool = "ponytail",
        version = "main",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "Invalid SemVer tag")
run("rm -f " .. shell_quote(tmp .. "/.agents/skills/ponytail/SKILL.md"))
expect_error(function()
    install:BackendInstall({
        tool = "ponytail",
        version = "v1.0.0",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "did not stage")

skill_file = assert(io.open(tmp .. "/.agents/skills/ponytail/SKILL.md", "w"))
skill_file:write("---\nname: ponytail\n---\n")
skill_file:close()
package.loaded.cmd = actual_cmd
local home = tmp .. "/home"
local codex_home = tmp .. "/codex"
local claude_home = tmp .. "/claude"
test_env = { HOME = home, CODEX_HOME = codex_home, CLAUDE_CONFIG_DIR = claude_home }
local original_getenv = os.getenv
os.getenv = function(name)
    return test_env[name]
end
run("mkdir -p " .. shell_quote(codex_home .. "/skills"))
run("ln -s " .. shell_quote(tmp .. "/.agents/skills/ponytail") .. " " .. shell_quote(codex_home .. "/skills/ponytail"))
run("mkdir -p " .. shell_quote(home .. "/.agents/skills/ponytail"))
local sentinel = assert(io.open(home .. "/.agents/skills/ponytail/sentinel", "w"))
sentinel:write("keep")
sentinel:close()
run("mkdir -p " .. shell_quote(home .. "/.cursor/skills"))
run("ln -s " .. shell_quote(tmp .. "/missing") .. " " .. shell_quote(home .. "/.cursor/skills/ponytail"))

local env_hook = load_hook("hooks/backend_exec_env.lua")
expect_error(function()
    env_hook:BackendExecEnv({
        tool = "ponytail",
        version = "v1.0.0",
        install_path = tmp,
        options = { source = "owner/repo" },
    })
end, "Refusing to replace non%-symlink")
assert(actual_file.exists(home .. "/.agents/skills/ponytail/sentinel"))
assert(not actual_file.exists(claude_home .. "/skills/ponytail"))
assert_equal(
    run("readlink " .. shell_quote(codex_home .. "/skills/ponytail")):gsub("%s+$", ""),
    tmp .. "/.agents/skills/ponytail"
)

run("rm -rf " .. shell_quote(home .. "/.agents/skills/ponytail"))
symlink_calls = {}
local result = env_hook:BackendExecEnv({
    tool = "ponytail",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "owner/repo" },
})
assert_equal(#result.env_vars, 0)
assert_equal(#symlink_calls, 4)
for _, destination in ipairs({
    codex_home .. "/skills/ponytail",
    claude_home .. "/skills/ponytail",
    home .. "/.agents/skills/ponytail",
    home .. "/.pi/agent/skills/ponytail",
    home .. "/.cursor/skills/ponytail",
}) do
    assert_equal(run("readlink " .. shell_quote(destination)):gsub("%s+$", ""), tmp .. "/.agents/skills/ponytail")
end

local default_home = tmp .. "/default-home"
test_env = { HOME = default_home }
symlink_calls = {}
env_hook:BackendExecEnv({
    tool = "ponytail",
    version = "v1.0.0",
    install_path = tmp,
    options = { source = "owner/repo" },
})
assert_equal(#symlink_calls, 5)
for _, destination in ipairs({
    default_home .. "/.codex/skills/ponytail",
    default_home .. "/.claude/skills/ponytail",
    default_home .. "/.agents/skills/ponytail",
    default_home .. "/.pi/agent/skills/ponytail",
    default_home .. "/.cursor/skills/ponytail",
}) do
    assert_equal(run("readlink " .. shell_quote(destination)):gsub("%s+$", ""), tmp .. "/.agents/skills/ponytail")
end

expect_error(function()
    env_hook:BackendExecEnv({
        tool = "ponytail",
        version = "v1.0.0",
        install_path = tmp .. "/missing-install",
        options = { source = "owner/repo" },
    })
end, "Staged skill is missing")

os.getenv = original_getenv
run("rm -rf " .. shell_quote(tmp))
print("hooks: ok")
