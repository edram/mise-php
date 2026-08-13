local file = require("file")
local json = require("json")

local M = {}

function M.load()
    local config_path = file.join_path(RUNTIME.pluginDirPath, "channels.json")
    local loaded, channels = pcall(function()
        return json.decode(file.read(config_path))
    end)

    if not loaded or type(channels) ~= "table" then
        error("Failed to load PHP channels from " .. config_path)
    end

    return channels
end

return M
