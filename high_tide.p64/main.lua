
local _modules = {}

function require(name)
    if _modules[name] == nil then
        local src_name = name:gsub('%.', '/') .. '.lua'
        _modules[name] = include(src_name)
    end
    return _modules[name]
end

include "src/main.lua"

include "lib/profiler.lua"

include "lib/error_explorer.lua"
