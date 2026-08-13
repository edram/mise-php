package.path = RUNTIME.pluginDirPath .. "/?.lua;" .. package.path

local archiver = require("archiver")
local cmd = require("cmd")
local file = require("file")
local http = require("http")
local json = require("json")
local channels = require("lib.channels").load()
local php = require("lib.php")

local COMPOSER_INSTALLER_URL = "https://getcomposer.org/installer"
local COMPOSER_SIGNATURE_URL = "https://composer.github.io/installer.sig"

local function download(url, path)
    local ok, download_error = http.try_download_file({
        url = url,
        headers = php.download_headers(),
    }, path)

    if download_error ~= nil or not ok then
        error("Failed to download " .. url .. ": " .. tostring(download_error or "unknown error"))
    end
end

local function install_composer(php_path, bin_path, download_path)
    local installer_path = file.join_path(download_path, "composer-setup.php")
    local composer_path = file.join_path(bin_path, "composer")

    download(COMPOSER_INSTALLER_URL, installer_path)

    -- Composer publishes the current installer's SHA-384 digest separately.
    -- See: https://getcomposer.org/download/
    local response, request_error = http.try_get({
        url = COMPOSER_SIGNATURE_URL,
        headers = php.download_headers(),
    })
    if request_error ~= nil or response == nil or response.status_code ~= 200 then
        error("Failed to download the Composer installer signature")
    end

    local expected = response.body:match("^%s*([0-9a-fA-F]+)%s*$")
    if expected == nil or #expected ~= 96 then
        error("Invalid Composer installer signature")
    end

    local hash_script = "echo hash_file('sha384', $argv[1]);"
    local actual = cmd.exec(
        php.shell_quote(php_path) .. " -r " .. php.shell_quote(hash_script) .. " " .. php.shell_quote(installer_path)
    ):match("([0-9a-fA-F]+)")
    if actual == nil or actual:lower() ~= expected:lower() then
        error("Composer installer signature verification failed")
    end

    cmd.exec(
        "COMPOSER_ALLOW_SUPERUSER=1 "
            .. php.shell_quote(php_path)
            .. " "
            .. php.shell_quote(installer_path)
            .. " --quiet "
            .. php.shell_quote("--install-dir=" .. bin_path)
            .. " --filename=composer"
    )
    os.remove(installer_path)
    cmd.exec(
        "COMPOSER_ALLOW_SUPERUSER=1 "
            .. php.shell_quote(php_path)
            .. " "
            .. php.shell_quote(composer_path)
            .. " --version --no-ansi"
    )
end

local function sha256(path)
    local hash_command = cmd.exec([[if command -v sha256sum >/dev/null 2>&1; then
        printf 'sha256sum'
    elif command -v shasum >/dev/null 2>&1; then
        printf 'shasum -a 256'
    fi]])

    if hash_command == "" then
        error("SHA-256 verification requires sha256sum or shasum")
    end

    local output = cmd.exec(hash_command .. " " .. php.shell_quote(path))
    local hash = output:match("^([0-9a-fA-F]+)")
    if hash == nil or #hash ~= 64 then
        error("Failed to calculate the SHA-256 checksum for " .. path)
    end

    return hash:lower()
end

local function release_asset_sha256(tag, archive_name)
    local response, request_error = http.try_get({
        url = php.release_api_url(tag),
        headers = php.api_headers(),
    })
    if request_error ~= nil then
        error("Failed to fetch PHP release metadata: " .. request_error)
    end
    if response == nil then
        error("GitHub Releases API returned no response")
    end
    if response.status_code ~= 200 then
        error("GitHub Releases API returned HTTP " .. response.status_code)
    end

    local decoded_ok, release = pcall(json.decode, response.body)
    if not decoded_ok or type(release) ~= "table" then
        error("Failed to parse the GitHub Release response")
    end

    local expected = php.release_asset_sha256(release, archive_name)
    if expected == nil then
        error("GitHub Release has no SHA-256 digest for " .. archive_name)
    end

    return expected
end

local function verify_sha256(archive_path, expected, archive_name)
    if sha256(archive_path) ~= expected:lower() then
        error("SHA-256 checksum mismatch for " .. archive_name)
    end
end

function PLUGIN:BackendInstall(ctx)
    local sapi = php.sapi(ctx.tool)
    local channel = php.channel(ctx, channels)
    local version = tostring(ctx.version or "")
    local install_path = tostring(ctx.install_path or "")
    local download_path = tostring(ctx.download_path or "")

    if not php.is_version(version) then
        error("Invalid PHP version: " .. version)
    end
    if install_path == "" then
        error("mise did not provide ctx.install_path")
    end
    if download_path == "" then
        error("mise did not provide ctx.download_path")
    end

    local platform = php.platform()
    local arch = php.arch()
    local tag = php.tag(version, sapi, channel)
    local archive_name = php.archive_name(version, sapi, channel, platform, arch)
    local archive_path = file.join_path(download_path, archive_name)
    local bin_path = file.join_path(install_path, "bin")
    local php_path = file.join_path(bin_path, "php")
    local expected_sha256 = release_asset_sha256(tag, archive_name)

    cmd.exec("mkdir -p " .. php.shell_quote(download_path) .. " " .. php.shell_quote(bin_path))
    download(php.download_url(tag, archive_name), archive_path)
    verify_sha256(archive_path, expected_sha256, archive_name)

    local extract_error = archiver.decompress(archive_path, bin_path)
    if extract_error ~= nil then
        error("Failed to extract " .. archive_name .. ": " .. extract_error)
    end
    if not file.exists(php_path) then
        error("PHP archive did not contain the php binary")
    end

    cmd.exec("chmod +x " .. php.shell_quote(php_path))
    if sapi == "cli" then
        install_composer(php_path, bin_path, download_path)
    end
    os.remove(archive_path)

    return {}
end
