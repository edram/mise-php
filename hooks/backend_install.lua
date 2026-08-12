package.path = RUNTIME.pluginDirPath .. "/?.lua;" .. package.path

local archiver = require("archiver")
local cmd = require("cmd")
local file = require("file")
local http = require("http")
local php = require("lib.php")

local function download(url, path)
    local ok, download_error = http.try_download_file({
        url = url,
        headers = php.download_headers(),
    }, path)

    if download_error ~= nil or not ok then
        error("Failed to download " .. url .. ": " .. tostring(download_error or "unknown error"))
    end
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

local function verify_checksum(archive_path, checksum_path, archive_name)
    local expected = php.checksum_for(file.read(checksum_path), archive_name)

    if sha256(archive_path) ~= expected:lower() then
        error("SHA-256 checksum mismatch for " .. archive_name)
    end
end

function PLUGIN:BackendInstall(ctx)
    local sapi = php.sapi(ctx.tool)
    local channel = php.channel(ctx)
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
    local checksum_path = file.join_path(download_path, php.CHECKSUMS_NAME)
    local bin_path = file.join_path(install_path, "bin")
    local php_path = file.join_path(bin_path, "php")

    cmd.exec("mkdir -p " .. php.shell_quote(download_path) .. " " .. php.shell_quote(bin_path))
    download(php.download_url(tag, archive_name), archive_path)
    download(php.download_url(tag, php.CHECKSUMS_NAME), checksum_path)
    verify_checksum(archive_path, checksum_path, archive_name)

    local extract_error = archiver.decompress(archive_path, bin_path)
    if extract_error ~= nil then
        error("Failed to extract " .. archive_name .. ": " .. extract_error)
    end
    if not file.exists(php_path) then
        error("PHP archive did not contain the php binary")
    end

    cmd.exec("chmod +x " .. php.shell_quote(php_path))
    os.remove(archive_path)
    os.remove(checksum_path)

    return {}
end
