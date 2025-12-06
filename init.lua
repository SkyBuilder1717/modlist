local http = core.request_http_api()
if not http then
    error("For better experience with 'modlist' mod, add mod into 'secure.http_mods' list!")
end
local modname = core.get_current_modname()
local Smodlist = core.get_translator(modname)

modlisting = {}

local function check_for_updates()
    for name, data in pairs(modlisting) do
        if data.author == "" or data.release == "" then
            goto continue
        end

        http.fetch({
            url = "https://content.luanti.org/api/packages/" .. data.author .. "/" .. name .. "/releases",
            timeout = 10,
            method = "GET",
    
        }, function(result)
            if result.timeout or not result.succeeded then
                modlisting[name].status = "failed"
                return
            end
            local release = core.parse_json(result.data)[1].id
            if release ~= tonumber(data.release) then
                modlisting[name].status = "update"
            else
                modlisting[name].status = "okay"
            end
        end)

        ::continue::
    end
end

local function scan_mods()
    for _, name in pairs(core.get_modnames()) do
        local path = core.get_modpath(name) .. "\\mod.conf"
        local f = io.open(path, "r")
        local content = f:read("*all")
        f:close()
        local title = content:match("title%s*=%s*(.-)\n") or content:match("title%s*=%s*(.-)$")
        local desc = content:match("description%s*=%s*(.-)\n") or content:match("description%s*=%s*(.-)$")
        local rel = content:match("release%s*=%s*(.-)\n") or content:match("release%s*=%s*(.-)$")
        local author = content:match("author%s*=%s*(.-)\n") or content:match("author%s*=%s*(.-)$")
        local S = core.get_translator(name)

        modlisting[name] = {title = title and S(title) or name, desc = desc and S(desc) or "", release = rel or "", author = author or "", status = ((author ~= "" and rel ~= "" and author ~= nil and rel ~= nil) and "progress") or ""}
    end
end

core.after(0, scan_mods)
if http then core.after(1, check_for_updates) end

if core.registered_chatcommands["mods"] then
    local COLOR_RED = "#f50"
    local COLOR_BLUE = "#7af"
    local COLOR_GREEN = "#7f7"
    local COLOR_CYAN = "#2bb"
    local COLOR_GRAY = "#bbb"

    local formspec = [[
            size[13,6.5]
            label[0,-0.1;%s]
            tablecolumns[color;tree;text;text,tooltip=%s;text,tooltip=%s]
            table[0,0.5;12.8,5.5;list;%s;0]
            button_exit[5,6;3,1;quit;%s]
        ]]

    local F = core.formspec_escape
    local Sbuiltin = core.get_translator("__builtin")

    local function build_mods_formspec(name)
        local rows = {}
        rows[1] = "#fff,0,ID,"..F(Smodlist("Mod Title"))..","..F(Sbuiltin("Description"))

        local updates = {}

        for name, data in pairs(modlisting) do
            rows[#rows + 1] = ("%s,0,%s,%s,%s"):format(
                (data.status == "update" and COLOR_BLUE) or (data.status == "failed" and COLOR_RED) or (data.status == "progress" and COLOR_CYAN) or (data.status == "okay" and COLOR_GREEN) or COLOR_GRAY,
                    name, (name ~= F(data.title) and F(data.title)) or "", F(data.desc))
        end
        
        local hints = F(Smodlist("* blue - needs an update")).."\n"..
            F(Smodlist("* green - checking finished successfully")).."\n"..
            F(Smodlist("* red - failed to check for updates")).."\n"..
            F(Smodlist("* cyan - check for updates is in progress")).."\n"..
            F(Smodlist("* grey - offline mod, doesn't need an update"))

        return formspec:format(
                F(Smodlist("Currently Installed mods") .. ":"),
                hints,
                hints,
                table.concat(rows, ","),
                F(Sbuiltin("Close"))
            )
    end

    local cmd_def = table.copy(core.registered_chatcommands["mods"])
    cmd_def.func = function(name)
        core.show_formspec(name, "modlist:modlist",
            build_mods_formspec(name))
        return true
    end

    core.override_chatcommand("mods", cmd_def)
else
    core.log("warning", "[" .. modname .. "] no /mods command found!")
end