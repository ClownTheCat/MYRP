-- Resistance faction
-- File name defines faction ID: "resistance".

FACTION.name = "Resistance"
FACTION.description = "Участники сопротивления, выступающие против оккупации Альянса."
FACTION.color = Color(145, 75, 65, 255)

-- In Helix, isDefault = true allows players to create characters in this faction
-- without requiring a whitelist. It does not prevent the other faction from being selectable.
FACTION.isDefault = true

-- Temporary vanilla models. Replace these paths when the Workshop collection is ready.
FACTION.models = {
    "models/humans/group03/male_01.mdl",
    "models/humans/group03/male_02.mdl",
    "models/humans/group03/male_03.mdl",
    "models/humans/group03/female_01.mdl",
    "models/humans/group03/female_02.mdl"
}

FACTION_RESISTANCE = FACTION.index
