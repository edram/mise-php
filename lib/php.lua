local M = {}

M.REPOSITORY = "edram/mise-php"
M.API_URL = "https://api.github.com/repos/" .. M.REPOSITORY
M.RELEASES_API_URL = M.API_URL .. "/releases?per_page=100"
M.RELEASES_URL = "https://github.com/" .. M.REPOSITORY .. "/releases/download"
M.USER_AGENT = "mise-php/" .. ((PLUGIN and PLUGIN.version) or "unknown")

M.SAPIS = {
    cli = true,
}

-- mise injects RUNTIME as userdata, so missing fields must be read defensively.
local function runtime_field(name)
    local ok, value = pcall(function()
        return RUNTIME[name]
    end)

    if not ok or value == nil or value == "" then
        error("mise did not provide RUNTIME." .. name)
    end

    return tostring(value)
end

-- Keeping the channel in the tool name gives each build its own mise install path.
function M.parse_tool(tool)
    local value = tostring(tool or "")
    local sapi, channel = value:match("^([a-z0-9]+)%-([a-z0-9][a-z0-9_-]*)$")
    if not M.SAPIS[sapi] then
        error("Unsupported PHP tool: " .. value .. ". Use php:cli-<channel>.")
    end

    return sapi, channel
end

function M.platform()
    local platform = runtime_field("osType"):lower()
    if platform == "linux" then
        return "linux"
    end
    if platform == "darwin" or platform == "macos" then
        return "macos"
    end

    error("Unsupported platform: " .. platform .. ". Use Linux or macOS.")
end

function M.arch()
    local arch = runtime_field("archType"):lower()
    if arch == "amd64" or arch == "x64" or arch == "x86_64" then
        return "x86_64"
    end
    if arch == "aarch64" or arch == "arm64" then
        return "aarch64"
    end

    error("Unsupported architecture: " .. arch .. ". Use x86_64 or aarch64.")
end

function M.is_version(version)
    return tostring(version or ""):match("^[0-9]+%.[0-9]+%.[0-9]+$") ~= nil
end

function M.version_from_tag(tag, sapi, channel)
    local version = tostring(tag or ""):match("^php%-([0-9]+%.[0-9]+%.[0-9]+)%-" .. sapi .. "%-" .. channel .. "$")
    if M.is_version(version) then
        return version
    end

    return nil
end

function M.tag(version, sapi, channel)
    if not M.is_version(version) then
        error("Invalid PHP version: " .. tostring(version or ""))
    end

    return "php-" .. version .. "-" .. sapi .. "-" .. channel
end

function M.archive_name(version, sapi, channel, platform, arch)
    return M.tag(version, sapi, channel) .. "-" .. platform .. "-" .. arch .. ".tar.gz"
end

function M.download_url(tag, filename)
    return M.RELEASES_URL .. "/" .. tag .. "/" .. filename
end

function M.release_api_url(tag)
    return M.API_URL .. "/releases/tags/" .. tag
end

function M.release_asset_sha256(release, filename)
    for _, asset in ipairs(release.assets or {}) do
        if asset.name == filename then
            local hash = tostring(asset.digest or ""):match("^sha256:([0-9a-fA-F]+)$")
            if hash ~= nil and #hash == 64 then
                return hash:lower()
            end

            return nil
        end
    end

    return nil
end

function M.download_headers()
    return {
        ["Accept"] = "application/gzip, application/octet-stream, */*",
        ["User-Agent"] = M.USER_AGENT,
    }
end

function M.api_headers()
    local headers = {
        ["Accept"] = "application/vnd.github+json",
        ["User-Agent"] = M.USER_AGENT,
        ["X-GitHub-Api-Version"] = "2022-11-28",
    }
    local token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN")
    if token ~= nil and token ~= "" then
        headers["Authorization"] = "Bearer " .. token
    end

    return headers
end

function M.shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

return M
