-- MYRP custom HUD plugin.
-- This plugin is deliberately separate from myrp_factionselect so HUD work
-- cannot break faction selection, TAB scoreboard, or the inventory module.

PLUGIN.name = "MYRP Custom HUD"
PLUGIN.author = "MYRP Development"
PLUGIN.description = "Custom Half-Life inspired HUD for MYRP."

-- Realm-specific files must be included explicitly by the plugin.
ix.util.Include("cl_plugin.lua", "client")
