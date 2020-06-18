local guidLoadLibFunc = "{50A9E9B7-C5F6-4e6e-A2FB-FA6DFDED741C}"
local guidSentinel    = "{7799A243-069B-4398-834B-FA3743CE0AA9}"
    --[[guidSentinel has been changed to be a value instead of a key.
    There was never any real guarantee that the sentinel value in 5.1
    is unique anyway, as it's a Light Userdata by default, a by-value
    type. The main problem we were having with the sentinel value is
    in the luaI_openlibs() function in the auxiliary library, which
    checks to see if a table already exists in package.loaded[modname]
    by checking to see if the value there is a table. Since the only
    by-reference value supported by Vanillin that's not a table is a
    Vanillin-created Full Userdata, and we can't create those until
    at least one instance of Vanillin is loaded, we essentially can't
    actually do that. (to clarify, Vanillin classifies non-Vanillin
    Full Userdata as tables when queried for the type of a value,
    because it has no way of getting the size of the userdata and thus
    can't really support meaningful operations on them.)
        But, since we're not exactly guaranteed of its uniqueness
    anyway, I think the next best solution is to use a value that
    might as well be impossible to generate by accident. 5.1 uses a
    light userdata corresponding to the address of a dummy internal
    variable, and I'll use a GUID.]]
local _R = debug.getregistry()

--Need to ensure this file is not executed twice somehow.
assert(not _R[guidLoadLibFunc])

local state_string = CLIENT and "clientside" or "serverside"
local opposite_state = CLIENT and "serverside" or "clientside"
local dll_prefix   = CLIENT and "gmcl_" or "gmsv_"
local dll_name     = dll_prefix .. "_LOADLIB_FUNC_win32.dll"


--[[First up, we need to see if require() is already correctly-working for us.
If it is, then we'll alert the user to the fact that this script is no longer necessary.
    The way the current test works goes like this:
    * require() currently looks in a cache which does not contain standard libraries
    * Additionally, require() currently does not ever return results, and often didn't
     return the one we wanted anyway. 
    Thus, if an error is raised (and caught here), it means require() still hasn't fixed
its cache. If the function passes successfully but returns nil, then it's not returning
any values. If the function passes successfully but returns a value not equal to the one
we know it should return, then it's not returning the correct value (most likely, it would
be returning boolean-true, instead of the actual library.)]]

do  local no_errors, returned_value = pcall(require, "string")
    if no_errors and (returned_value == _G.string) then
        --require() is working successfully.
        print(string.format(
            "Default require() function seems to be working %s, if it is also working %s then please remove require_compat.lua and %s",
            state_string, opposite_state, dll_name))
        return
    end
end

--If still here, we need to put in our own version of require()
require("_LOADLIB_FUNC")  --Module _LOADLIB_FUNC places a function equivalent to package.loadlib() into _R[guidLoadLibFunc]
assert(_R[guidLoadLibFunc])
        
local loadlib = _R[guidLoadLibFunc]
assert(_R._LOADED)
assert(package.preload)

--[[This table holds the (now-builtin) equivalents to package.loaders[] I may fill in the normal package.loaders[] table with these
entries later on in development, if I can't find a good reason not to]]
local loaders = {
    --Functionality of loader_preload() in loadlib.c
    function(modname)
        if type(package.preload) ~= "table" then
            error([['package.preload' must be a table]], 2)
        end
        
        return package.preload[modname] or string.format("\n\tno field package.preload['%s']", modname)
    end;
    
    --Functionality of loader_Lua() in loadlib.c, modified to use Garry's fixed path-searching functionality
    function(modname)
        local file_path = [[includes\modules\]] .. modname .. [[.lua]]
        local src_file = file.Open(file_path, "r", "LUA")
        
        if not src_file then
            return string.format("\n\tno file '%s'", file_path)
        end
        
        local file_text = src_file:Read(src_file:Size()); src_file:Close()
        local load_result = CompileString(file_text, "@" .. file_path, false)
        if type(load_result) == "string" then
            error(string.format(
                "error loading module '%s' from file '%s':\n\t%s",
                modname, file_path, load_result),
                3)
        end
        
        return load_result
    end;
    
    --Functionality of loader_C() in loadlib.c
    function(modname)
        --TODO: This filepath only finds binary modules in the global garrysmod\lua\bin\ folder, not in gamemode folders
        local file_path = [[garrysmod\lua\bin\]] .. dll_prefix .. modname:gsub("%.", [[\]]) .. [[_win32.dll]]
      --local entrypoint_name = "luaopen_" .. (modname:find("%-") and modname:match("^[^%-]*%-(.*)$") or modname):gsub("%.", "_")
        local entrypoint_name = "gmod13_open"
        
        local result, msg, reason = loadlib(file_path, entrypoint_name)
        
        --TODO: Need to better differentiate between no file, unlinkable file, file-doesn't-have-symbol
        if not result then
            assert((reason=="no_file") or (reason=="link_fail") or (reason=="no_func"), string.format("%s (%u)", reason, #reason))
            if reason == "no_file" then
                return string.format("\n\tno file '%s'", file_path)
            else
                error(string.format(
                    "error loading module '%s' from file '%s':\n\t%s",
                    modname, file_path, msg),
                    3)
            end
        end
        
        debug.setfenv(result, package)
        return result
    end;
    
    --Functionality of loader_Croot() in loadlib.c
    function(modname)
        --TODO: As before, this filepath only finds binary modules int he global garrysmod\lua\bin\ folder and not gamemode folders
        local file_path = [[garrysmod\lua\bin\]] .. dll_prefix .. modname:match("^([^%.]*)") .. [[_win32.dll]]
      --local entrypoint_name = "luaopen_" .. (modname:find("%-") and modname:match("^[^%-]*%-(.*)$") or modname):gsub("%.", "_")
        local entrypoint_name = "gmod13_open"
        
        local result, msg, reason = loadlib(file_path, entrypoint_name)
        --TODO: Again, need to better differentiate between no file, unlinkable file, file-doesn't-have-symbol
        if not result then
            assert((reason=="no_file") or (reason=="link_fail") or (reason=="no_func"), string.format("%s (%u)", reason, #reason))
            if reason == "no_file" then
                return string.format("\n\tno file '%s'", file_path)
            elseif reason == "link_fail" then
                error(string.format(
                    "error loading module '%s' from file '%s':\n\t%s",
                    modname, file_path, msg),
                    3)
            elseif reason == "no_func" then
                return string.format("\n\tno module '%s' in file '%s'", modname, filename)
            end
        end
        
        debug.setfenv(result, package)
        return result
    end;
}

local sentinel = guidSentinel

--New version of require() function
local function new_require(modname)
    assert(type(modname) == "string", type(modname))
    
    do local loaded_val = _R._LOADED[modname]
        if loaded_val == sentinel then
            error(string.format("loop or previous error loading module '%s'", modname), 2)
        elseif loaded_val ~= nil then
            return loaded_val
        end
    end
    
    local messages = {""}
    local loader   = nil
    
    for _,searcher in ipairs(loaders) do
        local result = searcher(modname)
        if type(result) == "function" then
            loader = result
            break
        elseif type(result) == "string" then
            messages[#messages+1] = result
        end
    end
    
    if not loader then
        error(string.format(
            "module '%s' not found:%s",
            modname, table.concat(messages)),
            2)
    else
        _R._LOADED[modname] = sentinel --So we can catch circular require()s
        local result = loader(modname)
        
        if result ~= nil then
            _R._LOADED[modname] = result
        end
        
        if _R._LOADED[modname] == sentinel then --Loader did not return a value or set a value
            _R._LOADED[modname] = true
        end
        
        return _R._LOADED[modname]
    end
end

_G.require = new_require