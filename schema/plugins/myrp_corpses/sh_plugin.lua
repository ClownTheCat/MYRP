PLUGIN.name = "MYRP Corpse Looting"
PLUGIN.author = "MYRP"
PLUGIN.description = "Moves dead players' inventories into searchable corpse inventories."

if (SERVER) then
    ix.util.Include("sv_plugin.lua")
else
    ix.util.Include("cl_plugin.lua", "client")
end
