-- Worker class for the Combine faction.
-- Internal class ID: "combine_worker". Display name: "Worker".

CLASS.name = "Worker"
CLASS.description = "Работник производственных объектов Альянса."
CLASS.isDefault = true

local faction = ix.faction.Get("combine")

if (faction) then
    CLASS.faction = faction.index
else
    ErrorNoHalt("[myrp] Faction 'combine' was not loaded before class 'combine_worker'. Check schema/factions/sh_combine.lua.\n")
end

CLASS_COMBINE_WORKER = CLASS.index
