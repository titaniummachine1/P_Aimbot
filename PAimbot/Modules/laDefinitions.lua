local laDefinitions = {
    [222]	= 11;		--Mad Milk                                      tf_weapon_jar_milk
    [812]	= 12;		--The Flying Guillotine                         tf_weapon_cleaver
    [833]	= 12;		--The Flying Guillotine (Genuine)               tf_weapon_cleaver
    [1121]	= 11;		--Mutated Milk                                  tf_weapon_jar_milk

    [18]	= -1;		--Rocket Launcher                               tf_weapon_rocketlauncher
    [205]	= -1;		--Rocket Launcher (Renamed/Strange)             tf_weapon_rocketlauncher
    [127]	= -1;		--The Direct Hit                                tf_weapon_rocketlauncher_directhit
    [228]	= -1;		--The Black Box                                 tf_weapon_rocketlauncher
    [237]	= -1;		--Rocket Jumper                                 tf_weapon_rocketlauncher
    [414]	= -1;		--The Liberty Launcher                          tf_weapon_rocketlauncher
    [441]	= -1;		--The Cow Mangler 5000                          tf_weapon_particle_cannon	
    [513]	= -1;		--The Original                                  tf_weapon_rocketlauncher
    [658]	= -1;		--Festive Rocket Launcher                       tf_weapon_rocketlauncher
    [730]	= -1;		--The Beggar's Bazooka                          tf_weapon_rocketlauncher
    [800]	= -1;		--Silver Botkiller Rocket Launcher Mk.I         tf_weapon_rocketlauncher
    [809]	= -1;		--Gold Botkiller Rocket Launcher Mk.I           tf_weapon_rocketlauncher
    [889]	= -1;		--Rust Botkiller Rocket Launcher Mk.I           tf_weapon_rocketlauncher
    [898]	= -1;		--Blood Botkiller Rocket Launcher Mk.I          tf_weapon_rocketlauncher
    [907]	= -1;		--Carbonado Botkiller Rocket Launcher Mk.I      tf_weapon_rocketlauncher
    [916]	= -1;		--Diamond Botkiller Rocket Launcher Mk.I        tf_weapon_rocketlauncher
    [965]	= -1;		--Silver Botkiller Rocket Launcher Mk.II        tf_weapon_rocketlauncher
    [974]	= -1;		--Gold Botkiller Rocket Launcher Mk.II          tf_weapon_rocketlauncher
    [1085]	= -1;		--Festive Black Box                             tf_weapon_rocketlauncher
    [1104]	= -1;		--The Air Strike                                tf_weapon_rocketlauncher_airstrike
    [15006]	= -1;		--Woodland Warrior                              tf_weapon_rocketlauncher
    [15014]	= -1;		--Sand Cannon                                   tf_weapon_rocketlauncher
    [15028]	= -1;		--American Pastoral                             tf_weapon_rocketlauncher
    [15043]	= -1;		--Smalltown Bringdown                           tf_weapon_rocketlauncher
    [15052]	= -1;		--Shell Shocker                                 tf_weapon_rocketlauncher
    [15057]	= -1;		--Aqua Marine                                   tf_weapon_rocketlauncher
    [15081]	= -1;		--Autumn                                        tf_weapon_rocketlauncher
    [15104]	= -1;		--Blue Mew                                      tf_weapon_rocketlauncher
    [15105]	= -1;		--Brain Candy                                   tf_weapon_rocketlauncher
    [15129]	= -1;		--Coffin Nail                                   tf_weapon_rocketlauncher
    [15130]	= -1;		--High Roller's                                 tf_weapon_rocketlauncher
    [15150]	= -1;		--Warhawk                                       tf_weapon_rocketlauncher

    [442]	= -1;		--The Righteous Bison                           tf_weapon_raygun

    [1178]	= -1;		--Dragon's Fury                                 tf_weapon_rocketlauncher_fireball

    [39]	= 8;		--The Flare Gun                                 tf_weapon_flaregun
    [351]	= 8;		--The Detonator                                 tf_weapon_flaregun
    [595]	= 8;		--The Manmelter                                 tf_weapon_flaregun_revenge
    [740]	= 8;		--The Scorch Shot                               tf_weapon_flaregun
    [1180]	= 0;		--Gas Passer                                    tf_weapon_jar_gas

    [19]	= 5;		--Grenade Launcher                              tf_weapon_grenadelauncher
    [206]	= 5;		--Grenade Launcher (Renamed/Strange)            tf_weapon_grenadelauncher
    [308]	= 5;		--The Loch-n-Load                               tf_weapon_grenadelauncher
    [996]	= 6;		--The Loose Cannon                              tf_weapon_cannon
    [1007]	= 5;		--Festive Grenade Launcher                      tf_weapon_grenadelauncher
    [1151]	= 4;		--The Iron Bomber                               tf_weapon_grenadelauncher
    [15077]	= 5;		--Autumn                                        tf_weapon_grenadelauncher
    [15079]	= 5;		--Macabre Web                                   tf_weapon_grenadelauncher
    [15091]	= 5;		--Rainbow                                       tf_weapon_grenadelauncher
    [15092]	= 5;		--Sweet Dreams                                  tf_weapon_grenadelauncher
    [15116]	= 5;		--Coffin Nail                                   tf_weapon_grenadelauncher
    [15117]	= 5;		--Top Shelf                                     tf_weapon_grenadelauncher
    [15142]	= 5;		--Warhawk                                       tf_weapon_grenadelauncher
    [15158]	= 5;		--Butcher Bird                                  tf_weapon_grenadelauncher

    [20]	= 1;		--Stickybomb Launcher                           tf_weapon_pipebomblauncher
    [207]	= 1;		--Stickybomb Launcher (Renamed/Strange)         tf_weapon_pipebomblauncher
    [130]	= 3;		--The Scottish Resistance                       tf_weapon_pipebomblauncher
    [265]	= 3;		--Sticky Jumper                                 tf_weapon_pipebomblauncher
    [661]	= 1;		--Festive Stickybomb Launcher                   tf_weapon_pipebomblauncher
    [797]	= 1;		--Silver Botkiller Stickybomb Launcher Mk.I     tf_weapon_pipebomblauncher
    [806]	= 1;		--Gold Botkiller Stickybomb Launcher Mk.I       tf_weapon_pipebomblauncher
    [886]	= 1;		--Rust Botkiller Stickybomb Launcher Mk.I       tf_weapon_pipebomblauncher
    [895]	= 1;		--Blood Botkiller Stickybomb Launcher Mk.I      tf_weapon_pipebomblauncher
    [904]	= 1;		--Carbonado Botkiller Stickybomb Launcher Mk.I  tf_weapon_pipebomblauncher
    [913]	= 1;		--Diamond Botkiller Stickybomb Launcher Mk.I    tf_weapon_pipebomblauncher
    [962]	= 1;		--Silver Botkiller Stickybomb Launcher Mk.II    tf_weapon_pipebomblauncher
    [971]	= 1;		--Gold Botkiller Stickybomb Launcher Mk.II      tf_weapon_pipebomblauncher
    [1150]	= 2;		--The Quickiebomb Launcher                      tf_weapon_pipebomblauncher
    [15009]	= 1;		--Sudden Flurry                                 tf_weapon_pipebomblauncher
    [15012]	= 1;		--Carpet Bomber                                 tf_weapon_pipebomblauncher
    [15024]	= 1;		--Blasted Bombardier                            tf_weapon_pipebomblauncher
    [15038]	= 1;		--Rooftop Wrangler                              tf_weapon_pipebomblauncher
    [15045]	= 1;		--Liquid Asset                                  tf_weapon_pipebomblauncher
    [15048]	= 1;		--Pink Elephant                                 tf_weapon_pipebomblauncher
    [15082]	= 1;		--Autumn                                        tf_weapon_pipebomblauncher
    [15083]	= 1;		--Pumpkin Patch                                 tf_weapon_pipebomblauncher
    [15084]	= 1;		--Macabre Web                                   tf_weapon_pipebomblauncher
    [15113]	= 1;		--Sweet Dreams                                  tf_weapon_pipebomblauncher
    [15137]	= 1;		--Coffin Nail                                   tf_weapon_pipebomblauncher
    [15138]	= 1;		--Dressed to Kill                               tf_weapon_pipebomblauncher
    [15155]	= 1;		--Blitzkrieg                                    tf_weapon_pipebomblauncher

    [588]	= -1;		--The Pomson 6000                               tf_weapon_drg_pomson
    [997]	= 9;		--The Rescue Ranger                             tf_weapon_shotgun_building_rescue

    [17]	= 10;		--Syringe Gun                                   tf_weapon_syringegun_medic
    [204]	= 10;		--Syringe Gun (Renamed/Strange)                 tf_weapon_syringegun_medic
    [36]	= 10;		--The Blutsauger                                tf_weapon_syringegun_medic
    [305]	= 9;		--Crusader's Crossbow                           tf_weapon_crossbow
    [412]	= 10;		--The Overdose                                  tf_weapon_syringegun_medic
    [1079]	= 9;		--Festive Crusader's Crossbow                   tf_weapon_crossbow

    [56]	= 7;		--The Huntsman                                  tf_weapon_compound_bow
    [1005]	= 7;		--Festive Huntsman                              tf_weapon_compound_bow
    [1092]	= 7;		--The Fortified Compound                        tf_weapon_compound_bow

    [58]	= 11;		--Jarate                                        tf_weapon_jar
    [1083]	= 11;		--Festive Jarate                                tf_weapon_jar
    [1105]	= 11;		--The Self-Aware Beauty Mark                    tf_weapon_jar
};


-- Function to create and return a table of item definitions
-- This table will map item definition indices to their respective categories.
local function CreateItemDefinitions(itemCategoryMappings)
    -- This table will hold the final item definitions.
    -- It will map each item definition index to its corresponding category.
    local itemDefinitionsTable = {}

    -- This variable will store the highest item definition index found in the input table.
    local maxItemDefinitionIndex = 0

    -- Loop through each key-value pair in the input table (itemCategoryMappings).
    -- The key is the item definition index, and the value is the category.
    for itemDefinitionIndex, _ in pairs(itemCategoryMappings) do
        -- Update the maxItemDefinitionIndex if the current itemDefinitionIndex is larger.
        maxItemDefinitionIndex = math.max(maxItemDefinitionIndex, itemDefinitionIndex)
    end

    -- Now that we know the highest item definition index, we can fill our itemDefinitionsTable.
    -- We loop from 1 to maxItemDefinitionIndex to ensure all indices are covered.
    for i = 1, maxItemDefinitionIndex do
        -- If the itemCategoryMappings table has a value for this index, use it.
        -- If not, assign false to this index.
        itemDefinitionsTable[i] = itemCategoryMappings[i] or false
    end

    -- Return the populated itemDefinitionsTable, which maps each item index to its category.
    return itemDefinitionsTable
end

-- We call the CreateItemDefinitions function, passing in our example mappings.
-- This will return a table that maps each item definition index to its corresponding category.
local aItemDefinitions = CreateItemDefinitions(laDefinitions)

return aItemDefinitions