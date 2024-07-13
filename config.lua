Config = {}

-- Cow spawn settings
Config.CowSpawnLocation = vector3(93.27, 220.79, 111.47)
Config.CowSpawnHeading = 180.0 -- Facing South
Config.NumberOfCows = 5
Config.CowModel = "a_c_cow"
Config.CowBlipSprite = GetHashKey("blip_ambient_ped_medium")  -- You may need to find the appropriate sprite hash for a cow blip
Config.CowBlipText = "Rustled Cow"

-- Bandit spawn settings
Config.BanditSpawnLocation = vector3(100.09, 238.70, 113.60 -1)
Config.BanditSpawnHeading = 270.0 -- Facing West
Config.NumberOfBandits = 4
Config.BanditModel = "g_m_m_uniranchers_01"
Config.HorseModel = "a_c_horse_kentuckysaddle_black"

-- Selling settings
Config.SellNPCLocation = vector3(-374.39, -341.21, 87.58)
Config.SellNPCModel = "u_m_m_valbutcher_01"
Config.SellNPCHeading = 0.0 -- Facing North
Config.SellingRadius = 5.0
Config.PricePerCow = 50
Config.MissionTriggerRadius = 50.0
Config.CowSellDistance = 10.0 

Config.AddGPSRoute = true


Config.SellPointBlip = {
    name = 'Auction yard',
    sprite = 423351566,
    x = -373.57,
    y = -343.24,
    z = 87.28
}



Config.BanditAggroRadius = 20.0  -- Distance at which bandits become aggressive
Config.BanditAttackInterval = 5000  -- Time in ms between bandit attacks


Config.PoliceJobName = "leo"


Config.MissionResetTime = 45