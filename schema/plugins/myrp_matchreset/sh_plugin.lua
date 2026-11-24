PLUGIN.name = "MYRP Match Reset"
PLUGIN.author = "MYRP"
PLUGIN.description = "Coordinates safe round cleanup, character return to faction selection, and same-process map reloads."

if SERVER then
    ix.util.Include(PLUGIN.folder .. "/sv_plugin.lua")
end