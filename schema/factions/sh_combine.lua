-- Combine faction
-- File name defines faction ID: "combine".

FACTION.name = "Combine"
FACTION.description = "Рабочие под контролем Альянса. Производство и снабжение поддерживают инфраструктуру Combine."
FACTION.color = Color(65, 95, 135, 255)

-- In Helix, isDefault = true allows players to create characters in this faction
-- without requiring a whitelist. It does not prevent the other faction from being selectable.
FACTION.isDefault = true

-- Temporary vanilla models. Replace these paths when the Workshop collection is ready.
FACTION.models = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_04.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_02.mdl"
}

FACTION_COMBINE = FACTION.index
