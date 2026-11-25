PLUGIN.name = "MYRP Supply"
PLUGIN.author = "MYRP"
PLUGIN.description = "Faction supply terminals, timed cargo drops and recoverable supply crates."

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

MYRP.Supply.imgui = ix.util.Include("imgui.lua", "client")

ix.util.Include("cl_plugin.lua", "client")
ix.util.Include("sv_plugin.lua", "server")
