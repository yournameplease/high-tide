
local _modules = {}

function require(name)
    if _modules[name] == nil then
        local src_name = name:gsub('%.', '/') .. '.lua'
        _modules[name] = include(src_name)
    end
    return _modules[name]
end

DATP = ""
cp("/projects/games/high-tide/src", "src")
cp("/projects/games/high-tide/lib", "lib")

include "src/main.lua"

include "lib/profiler.lua"

include "lib/error_explorer.lua"
