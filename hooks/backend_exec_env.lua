local file = require("file")

function PLUGIN:BackendExecEnv(ctx)
    local bin_path = file.join_path(ctx.install_path, "bin")
    local env_vars = {
        { key = "PATH", value = bin_path },
    }
    local conf_path = file.join_path(bin_path, "conf.d")
    local sqlsrv_ini_path = file.join_path(conf_path, "20-sqlsrv.ini")

    if file.exists(sqlsrv_ini_path) then
        table.insert(env_vars, {
            key = "MISE_PHP_EXTENSION_DIR",
            value = file.join_path(bin_path, "extensions"),
        })
        -- The empty path segment preserves PHP's compiled-in conf.d directory.
        table.insert(env_vars, {
            key = "PHP_INI_SCAN_DIR",
            value = ":" .. conf_path,
        })
    end

    return {
        env_vars = env_vars,
    }
end
