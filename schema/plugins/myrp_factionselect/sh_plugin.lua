PLUGIN.name = "MYRP Faction Selection"
PLUGIN.author = "OpenAI"
PLUGIN.description = "Custom Combine / Resistance faction and Worker selection screen."

-- Helix loads sh_plugin.lua automatically, but realm-specific files must be included explicitly.
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
