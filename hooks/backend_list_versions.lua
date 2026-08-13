package.path = RUNTIME.pluginDirPath .. "/?.lua;" .. package.path

local http = require("http")
local json = require("json")
local semver = require("semver")
local channels = require("lib.channels").load()
local php = require("lib.php")

function PLUGIN:BackendListVersions(ctx)
    local sapi = php.sapi(ctx.tool)
    local channel = php.channel(ctx, channels)
    local platform = php.platform()
    local arch = php.arch()

    local response, request_error = http.try_get({
        url = php.RELEASES_API_URL,
        headers = php.api_headers(),
    })
    if request_error ~= nil then
        error("Failed to fetch PHP releases: " .. request_error)
    end
    if response == nil then
        error("GitHub Releases API returned no response")
    end
    if response.status_code ~= 200 then
        error("GitHub Releases API returned HTTP " .. response.status_code)
    end

    local decoded_ok, releases = pcall(json.decode, response.body)
    if not decoded_ok or type(releases) ~= "table" then
        error("Failed to parse the GitHub Releases response")
    end

    local versions = {}
    for _, release in ipairs(releases) do
        if not release.draft and not release.prerelease then
            local version = php.version_from_tag(release.tag_name, sapi, channel)
            local archive_name = version and php.archive_name(version, sapi, channel, platform, arch)

            if archive_name and php.release_asset_sha256(release, archive_name) then
                table.insert(versions, version)
            end
        end
    end

    if #versions == 0 then
        error("No " .. channel .. " PHP CLI builds are available for " .. platform .. "-" .. arch)
    end

    return { versions = semver.sort(versions) }
end
