PLUGIN.name = "MYRP Supply"
PLUGIN.author = "MYRP"
PLUGIN.description = "Faction supply terminals, timed cargo drops and recoverable supply crates."

print("[MYRP:SUPPLY][LOAD] sh_plugin.lua started; realm=" .. (SERVER and "SERVER" or "CLIENT"))

MYRP = MYRP or {}
MYRP.Supply = MYRP.Supply or {}

MYRP.Supply.Terminals = {
    combine = "models/props_combine/combine_intmonitor001.mdl",
    resistance = "models/props_lab/workspace002.mdl"
}

MYRP.Supply.Crates = {
    combine = "models/props_combine/headcrabcannister01a.mdl",
    resistance = "models/props/cs_militia/crate_extralargemill.mdl"
}

MYRP.Supply.RequestCooldown = 15 * 60
MYRP.Supply.DeliveryDelay = 30
MYRP.Supply.OpenDuration = 5

print("[MYRP:SUPPLY][LOAD] including imgui.lua; realm=" .. (SERVER and "SERVER" or "CLIENT"))
ix.util.Include("imgui.lua", "client")
print("[MYRP:SUPPLY][LOAD] imgui include returned " .. (istable(MYRP.Supply.imgui) and "table" or tostring(MYRP.Supply.imgui)))

print("[MYRP:SUPPLY][LOAD] including cl_plugin.lua")
ix.util.Include("cl_plugin.lua", "client")
print("[MYRP:SUPPLY][LOAD] cl_plugin include call completed")

print("[MYRP:SUPPLY][LOAD] including sv_plugin.lua")
ix.util.Include("sv_plugin.lua", "server")
print("[MYRP:SUPPLY][LOAD] sh_plugin.lua completed")
