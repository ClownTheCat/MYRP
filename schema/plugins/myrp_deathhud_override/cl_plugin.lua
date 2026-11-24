-- MYRP Helix Death HUD Override v1.0
-- The installed MYRP Helix build draws its native black death fade and
-- "YOU ARE DEAD" text inside ix.hud.DrawDeath() in core/libs/cl_hud.lua.
-- ix.hud.DrawAll(postHook) calls ix.hud.DrawDeath() dynamically, so replacing
-- this one function leaves DrawItemPickup() and the rest of the HUD intact.

if not CLIENT then return end

local PLUGIN = PLUGIN
local HOOK_ID = "MYRP.DeathHUD.OverrideHelixDrawDeath"
local STATUS_COMMAND = "myrp_deathhud_status"

local function DisabledHelixDeathDraw()
    -- Intentionally empty: MYRP Match Flow draws its own white death text
    -- and countdown through DrawOverlay.
end

local function InstallOverride(reason)
    if not ix or not istable(ix.hud) then
        return false
    end

    if not isfunction(ix.hud.DrawDeath) then
        return false
    end

    if ix.hud.DrawDeath ~= DisabledHelixDeathDraw then
        PLUGIN.originalDrawDeath = PLUGIN.originalDrawDeath or ix.hud.DrawDeath
        ix.hud.DrawDeath = DisabledHelixDeathDraw

        MsgC(Color(105, 190, 150),
            "[MYRP:DEATHHUD][CLIENT][INFO] Disabled native ix.hud.DrawDeath; reason=",
            Color(220, 220, 220), tostring(reason or "unknown"), "\n")
    end

    return ix.hud.DrawDeath == DisabledHelixDeathDraw
end

-- Helix core libraries are normally loaded before schema plugins. Install
-- immediately, then retry from Think in case another plugin reloads cl_hud.lua.
InstallOverride("plugin init")

hook.Add("Think", HOOK_ID, function()
    if not ix or not istable(ix.hud) then return end

    if ix.hud.DrawDeath ~= DisabledHelixDeathDraw then
        InstallOverride("Think watchdog")
    end
end)

hook.Add("OnReloaded", HOOK_ID, function()
    InstallOverride("OnReloaded")
end)

concommand.Add(STATUS_COMMAND, function()
    local active = ix and ix.hud and ix.hud.DrawDeath == DisabledHelixDeathDraw

    MsgC(Color(105, 190, 150), "[MYRP:DEATHHUD][CLIENT][INFO] STATUS ",
        Color(220, 220, 220),
        "nativeDrawDeathDisabled=" .. tostring(active == true),
        ", drawAllPreserved=" .. tostring(ix and ix.hud and isfunction(ix.hud.DrawAll) or false),
        "\n")
end)

MsgC(Color(105, 190, 150),
    "[MYRP:DEATHHUD][CLIENT][INFO] Override module loaded; target=ix.hud.DrawDeath\n")
