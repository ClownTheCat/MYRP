PLUGIN.name = "MYRP Match Flow"
PLUGIN.author = "MYRP"
PLUGIN.description = "Persistent faction lock, 30-second profession respawn, match clock and faction kill scoreboard (v2.0)."

-- Keep the existing Match Flow implementation intact. The match HUD is an
-- additive pair of modules so it does not touch the existing death-screen UI.
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_matchhud.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_matchhud.lua")
