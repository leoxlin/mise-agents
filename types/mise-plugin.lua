--- Minimal LuaCATS definitions for mise backend plugins.

---@class Runtime
---@field osType string
---@field archType string
---@field pluginDirPath string
RUNTIME = {}

---@class BackendOptions
---@field source string

---@class BackendListVersionsCtx
---@field tool string
---@field options? BackendOptions

---@class BackendListVersionsResult
---@field versions string[]

---@class BackendInstallCtx
---@field tool string
---@field version string
---@field install_path string
---@field options? BackendOptions

---@class BackendInstallResult

---@class BackendExecEnvCtx
---@field tool string
---@field version string
---@field install_path string
---@field options? BackendOptions

---@class EnvKey
---@field key string
---@field value string

---@class BackendExecEnvResult
---@field env_vars EnvKey[]

---@class Plugin
---@field BackendListVersions? fun(self: Plugin, ctx: BackendListVersionsCtx): BackendListVersionsResult
---@field BackendInstall? fun(self: Plugin, ctx: BackendInstallCtx): BackendInstallResult
---@field BackendExecEnv? fun(self: Plugin, ctx: BackendExecEnvCtx): BackendExecEnvResult
PLUGIN = {}

return nil
