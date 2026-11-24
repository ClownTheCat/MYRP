-- Worker class for the Resistance faction.
-- Internal class ID: "resistance_worker". Display name: "Worker".

CLASS.name = "Worker"
CLASS.description = "Работник производственных объектов Сопротивления."
CLASS.isDefault = true

local faction = ix.faction.Get("resistance")

if (faction) then
    CLASS.faction = faction.index
else
    ErrorNoHalt("[myrp] Faction 'resistance' was not loaded before class 'resistance_worker'. Check schema/factions/sh_resistance.lua.\n")
end

CLASS_RESISTANCE_WORKER = CLASS.index
