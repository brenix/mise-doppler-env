-- Simple JSON parser for Doppler secrets
local function parse_json(json_str)
    -- Remove leading/trailing whitespace
    json_str = json_str:match("^%s*(.-)%s*$")

    -- Basic JSON object parser (assumes top-level is an object)
    if not json_str:match("^%{.*%}$") then
        return {}
    end

    local secrets = {}
    -- Remove outer braces
    local content = json_str:match("^%{(.*)%}$")

    -- Parse key-value pairs
    local in_value = false
    local in_escape = false
    local current_key = nil
    local current_value = ""
    local brace_depth = 0

    local i = 1
    while i <= #content do
        local char = content:sub(i, i)

        if not in_value then
            -- Looking for key
            local rest = content:sub(i)
            local key = rest:match('^%s*"([^"]+)"%s*:%s*"')
            if key and key:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                current_key = key
                current_value = ""
                in_value = true
                -- Skip to opening quote of value
                i = i + #rest:match('^%s*"[^"]+"%s*:%s*"') - 1
            end
        else
            -- Reading value
            if in_escape then
                -- Handle escape sequences
                if char == "n" then
                    current_value = current_value .. "\n"
                elseif char == "t" then
                    current_value = current_value .. "\t"
                elseif char == "\\" then
                    current_value = current_value .. "\\"
                elseif char == '"' then
                    current_value = current_value .. '"'
                else
                    current_value = current_value .. char
                end
                in_escape = false
            elseif char == "\\" then
                in_escape = true
            elseif char == '"' then
                -- End of value
                secrets[current_key] = current_value
                current_key = nil
                current_value = ""
                in_value = false
            else
                current_value = current_value .. char
            end
        end

        i = i + 1
    end

    return secrets
end

function PLUGIN:MiseEnv(ctx)
    local env_vars = {}

    -- Get Doppler project and config from options or environment variables
    local project = nil
    local config = nil

    if ctx.options then
        project = ctx.options.project
        config = ctx.options.config
    end

    project = project or os.getenv("DOPPLER_PROJECT")
    config = config or os.getenv("DOPPLER_CONFIG")

    -- Only fetch if we have the required configuration
    if project and config then
        local config_dir = os.getenv("MISE_CONFIG_DIR") or os.getenv("PWD") or "."
        local cache_file = config_dir .. "/.secrets.json"
        local cache_ttl = 0 -- Disabled by default (0 = no caching)

        -- Check if cache_ttl is configured in options
        if ctx.options and ctx.options.cache_ttl then
            cache_ttl = tonumber(ctx.options.cache_ttl) or 0
        end

        local json_output = nil
        local use_cache = false

        -- Check if cache file exists and is fresh (only if caching is enabled)
        if cache_ttl > 0 then
            local cache = io.open(cache_file, "r")
            if cache then
                cache:close()
                -- Get file modification time
                -- Use native macOS stat if available, otherwise try Linux format
                local stat_cmd
                local is_macos = io.popen("uname"):read("*line") == "Darwin"
                if is_macos then
                    -- Use native macOS stat command explicitly to avoid conflicts other installed binaries
                    stat_cmd = string.format('/usr/bin/stat -f "%%m" "%s" 2>/dev/null', cache_file)
                else
                    stat_cmd = string.format('stat -c "%%Y" "%s" 2>/dev/null', cache_file)
                end

                local stat_handle = io.popen(stat_cmd)
                if stat_handle then
                    local mtime_str = stat_handle:read("*line")
                    stat_handle:close()
                    local mtime = tonumber(mtime_str)
                    local now = os.time()

                    if mtime and (now - mtime) < cache_ttl then
                        use_cache = true
                        cache = io.open(cache_file, "r")
                        if cache then
                            json_output = cache:read("*all")
                            cache:close()
                        end
                    end
                end
            end
        end

        -- Fetch from Doppler if cache is stale or missing
        if not use_cache then
            local cmd = string.format(
                'DOPPLER_PROJECT=%s DOPPLER_CONFIG=%s doppler secrets download --no-file --format json 2>/dev/null',
                project, config
            )

            local handle = io.popen(cmd)
            if handle then
                json_output = handle:read("*all")
                handle:close()

                -- Write to cache file (only if caching is enabled)
                if cache_ttl > 0 and json_output and json_output ~= "" then
                    local cache_write = io.open(cache_file, "w")
                    if cache_write then
                        cache_write:write(json_output)
                        cache_write:close()
                    end
                end
            end
        end

        -- Parse JSON and populate env_vars
        if json_output and json_output ~= "" then
            local secrets = parse_json(json_output)

            for key, value in pairs(secrets) do
                table.insert(env_vars, {
                    key = key,
                    value = value
                })
            end
        end
    end

    return env_vars
end
