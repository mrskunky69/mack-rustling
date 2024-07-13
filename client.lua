local RSGCore = exports['rsg-core']:GetCoreObject()

-- Mission variables
local cows = {}
local bandits = {}
local cowBlips = {}
local missionStarted = false
local isCowsAttached = false
local rustlingPlayer = nil
local sellPointMarker = nil
local horses = {}



-- Utility functions
local function GetRandomHeading()
    return math.random() * 360.0
end

local function AddBlipForCow(cow)
    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, 1664425300, cow)
    SetBlipSprite(blip, Config.CowBlipSprite)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.CowBlipText)
    return blip
end

local function NotifyRustlingPlayer(title, message)
    if rustlingPlayer == PlayerId() then
        TriggerEvent('rNotify:NotifyLeft', title, message, "generic_textures", "tick", 4000)
    end
end

-- Entity spawning functions
local function SpawnCows()
    local cowHash = GetHashKey(Config.CowModel)
    RequestModel(cowHash)
    while not HasModelLoaded(cowHash) do
        Citizen.Wait(100)
    end

    for i = 1, Config.NumberOfCows do
        local x = Config.CowSpawnLocation.x + (math.random() - 0.5) * 10.0
        local y = Config.CowSpawnLocation.y + (math.random() - 0.5) * 10.0
        local z = Config.CowSpawnLocation.z
        local heading = GetRandomHeading()
        local cow = CreatePed(cowHash, x, y, z, heading, true, false)
        table.insert(cows, cow)
        Citizen.InvokeNative(0x283978A15512B2FE, cow, true)
        
        local blip = AddBlipForCow(cow)
        table.insert(cowBlips, blip)
    end
    SetModelAsNoLongerNeeded(cowHash)
end

local function SpawnBandits()
    local banditHash = GetHashKey(Config.BanditModel)
    local horseHash = GetHashKey(Config.HorseModel)
    
    RequestModel(banditHash)
    RequestModel(horseHash)
    
    while not HasModelLoaded(banditHash) or not HasModelLoaded(horseHash) do
        Citizen.Wait(100)
    end

    for i = 1, Config.NumberOfBandits do
        local x = Config.BanditSpawnLocation.x + (math.random() - 0.5) * 15.0
        local y = Config.BanditSpawnLocation.y + (math.random() - 0.5) * 15.0
        local z = Config.BanditSpawnLocation.z
        local heading = GetRandomHeading()
        
        local horse = CreatePed(horseHash, x, y, z, heading, true, false)
        local bandit = CreatePed(banditHash, x, y, z, heading, true, false)
        
        Citizen.InvokeNative(0x283978A15512B2FE, horse, true)
        Citizen.InvokeNative(0x283978A15512B2FE, bandit, true)
        
        Citizen.InvokeNative(0x028F76B6E78246EB, bandit, horse, -1)  -- Set bandit on horse
        
        table.insert(bandits, bandit)
        table.insert(horses, horse)  -- Add horse to the horses table
    end
    
    SetModelAsNoLongerNeeded(banditHash)
    SetModelAsNoLongerNeeded(horseHash)
end

-- Mission logic functions
local function AreBanditsDead()
    for _, bandit in ipairs(bandits) do
        if DoesEntityExist(bandit) and not IsEntityDead(bandit) then
            return false
        end
    end
    return true
end

local function MakeCowFollow(cow, player)
    Citizen.CreateThread(function()
        while DoesEntityExist(cow) and not IsEntityDead(cow) do
            local playerCoords = GetEntityCoords(player)
            local cowCoords = GetEntityCoords(cow)
            local distance = #(playerCoords - cowCoords)
            
            if distance > 3.0 then
                TaskGoToEntity(cow, player, -1, 2.0, 2.0, 0, 0)
            else
                ClearPedTasks(cow)
            end
            
            Citizen.Wait(1000)
        end
    end)
end

local function AttachCowsToNearestPlayer()
    local playerPed = PlayerPedId()
    rustlingPlayer = PlayerId()
    
    for _, cow in ipairs(cows) do
        if DoesEntityExist(cow) and not IsEntityDead(cow) then
            Citizen.InvokeNative(0x3AD51CAB001A6108, cow, true)  -- Set animal as being led
            SetBlockingOfNonTemporaryEvents(cow, true)
            TaskFollowToOffsetOfEntity(cow, playerPed, 0.0, -3.0, 0.0, 1.0, -1, 1.0, true)
            
            MakeCowFollow(cow, playerPed)
            TriggerServerEvent("rustling:SetRustlingPlayer", GetPlayerServerId(rustlingPlayer))
        end
    end
    
    isCowsAttached = true 
	TriggerEvent('rNotify:NotifyLeft', "The cows are now following you", "Lead them to the selling point.", "generic_textures", "tick", 4000)
end

local function IsNearSellingPoint()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local sellPointDistance = #(playerCoords - Config.SellNPCLocation)
    
    if sellPointDistance <= Config.SellingRadius then
        -- Player is near, now check cows
        local allCowsNear = true
        for _, cow in ipairs(cows) do
            if DoesEntityExist(cow) and not IsEntityDead(cow) then
                local cowCoords = GetEntityCoords(cow)
                local cowDistance = #(cowCoords - Config.SellNPCLocation)
                if cowDistance > Config.CowSellDistance then
                    allCowsNear = false
                    break
                end
            end
        end
        return allCowsNear
    end
    return false
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if missionStarted and isCowsAttached then
            DrawMarker(1, Config.SellNPCLocation.x, Config.SellNPCLocation.y, Config.SellNPCLocation.z - 1.0, 
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                Config.CowSellDistance * 2, Config.CowSellDistance * 2, 1.0, 
                255, 255, 0, 100, false, true, 2, false, nil, nil, false)
        end
    end
end)

local function StartMission()
    if not missionStarted then
        missionStarted = true
        SpawnCows()
        SpawnBandits()
        TriggerEvent('rNotify:NotifyLeft', "Rustling", "Mission started! Defeat the bandits and rustle the cows.", "generic_textures", "tick", 4000)
        TriggerServerEvent("rustling:SetActiveMissionPlayer")
    end
end

RegisterNetEvent("rustling:StartMission")
AddEventHandler("rustling:StartMission", function()
    StartMission()
end)

local function ResetMission()
    for _, cow in ipairs(cows) do
        if DoesEntityExist(cow) then
            DeleteEntity(cow)
        end
    end
    for _, bandit in ipairs(bandits) do
        if DoesEntityExist(bandit) then
            DeleteEntity(bandit)
        end
    end
    for _, horse in ipairs(horses) do  -- Add this loop to delete horses
        if DoesEntityExist(horse) then
            DeleteEntity(horse)
        end
    end
    cows = {}
    bandits = {}
    horses = {}  -- Reset the horses table
    cowBlips = {}
    isCowsAttached = false
    missionStarted = false
    rustlingPlayer = nil
    
    -- Clear GPS route if it was added
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
    end
end



Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)  -- Changed to 0 for more responsive checks
        
        if missionStarted then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            if not isCowsAttached then
                if AreBanditsDead() then
                    local nearCow = false
                    
                    for _, cow in ipairs(cows) do
                        if DoesEntityExist(cow) and not IsEntityDead(cow) then
                            local cowCoords = GetEntityCoords(cow)
                            local distance = #(playerCoords - cowCoords)
                            
                            if distance < 5.0 then
                                nearCow = true
                                break
                            end
                        end
                    end
                    
                    if nearCow then
                        AttachCowsToNearestPlayer()
                        TriggerServerEvent("rustling:NotifyPolice")
                        TriggerEvent('rNotify:NotifyLeft', "All bandits are dead!", " Round up the Cows and take them to the Auction Yard.", "generic_textures", "tick", 4000)
                        
                        -- Add GPS route when cows are attached
                        if Config.AddGPSRoute then
                            StartGpsMultiRoute(GetHashKey("COLOR_RED"), true, true)
                            AddPointToGpsMultiRoute(Config.SellNPCLocation.x, Config.SellNPCLocation.y, Config.SellNPCLocation.z)
                            SetGpsMultiRouteRender(true)
                        end
                    end
                else
                    -- Check if player is near bandits and trigger combat if necessary
                    for _, bandit in ipairs(bandits) do
                        if DoesEntityExist(bandit) and not IsEntityDead(bandit) then
                            local banditCoords = GetEntityCoords(bandit)
                            local distance = #(playerCoords - banditCoords)
                            
                            if distance < Config.BanditAggroRadius then
                                TaskCombatPed(bandit, playerPed, 0, 16)
                            end
                        end
                    end
                end
            else
                local sellPointDistance = #(playerCoords - Config.SellNPCLocation)
                
                if sellPointDistance <= Config.SellingRadius then
                    local allCowsNear = true
                    for _, cow in ipairs(cows) do
                        if DoesEntityExist(cow) and not IsEntityDead(cow) then
                            local cowCoords = GetEntityCoords(cow)
                            local cowDistance = #(cowCoords - Config.SellNPCLocation)
                            if cowDistance > Config.CowSellDistance then
                                allCowsNear = false
                                break
                            end
                        end
                    end

                    if allCowsNear then
                        TriggerServerEvent("rustling:SellCows", #cows)
                        ResetMission()
                        TriggerEvent('rNotify:NotifyLeft', "COMPLETED!", " COWS SOLD SUCCESSFULLY.", "generic_textures", "tick", 4000)
                        
                        -- Clear GPS route when mission is completed
                        if Config.AddGPSRoute then
                            ClearGpsMultiRoute()
                        end
                    else
                        TriggerEvent('rNotify:NotifyLeft', "Almost there!", "Make sure all cows are close to the sell point.", "generic_textures", "tick", 4000)
                    end
                else
                    -- Check if all cows are still following
                    local allCowsFollowing = true
                    for _, cow in ipairs(cows) do
                        if DoesEntityExist(cow) and not IsEntityDead(cow) then
                            local cowCoords = GetEntityCoords(cow)
                            local distance = #(playerCoords - cowCoords)
                            
                            if distance > 10.0 then  -- Adjust this distance as needed
                                allCowsFollowing = false
                                break
                            end
                        end
                    end
                    
                 
                end
            end

           

            
        end
    end
end)

-- Add this function for drawing 3D text
function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        SetTextColor(255, 255, 255, 215)
        SetTextCentre(1)
        DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
    end
end

Citizen.CreateThread(function()
    local blip = N_0x554d9d53f696d002(1664425300, Config.SellPointBlip.x, Config.SellPointBlip.y, Config.SellPointBlip.z)
    SetBlipSprite(blip, Config.SellPointBlip.sprite, 1)
    SetBlipScale(blip, 0.2)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.SellPointBlip.name)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if missionStarted and isCowsAttached then
            DrawMarker(1, Config.SellPointBlip.x, Config.SellPointBlip.y, Config.SellPointBlip.z - 1.0, 
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                2.0, 2.0, 1.0, 255, 0, 0, 200, false, true, 2, false, nil, nil, false)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)  -- Check every second
        if not missionStarted then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distanceToBanditArea = #(playerCoords - Config.BanditSpawnLocation)
            
            if distanceToBanditArea <= Config.MissionTriggerRadius then
                TriggerServerEvent("rustling:RequestMissionStart")
            end
        end
    end
end)


RegisterNetEvent("rustling:SaleComplete")
AddEventHandler("rustling:SaleComplete", function(reward)
    TriggerEvent('rNotify:NotifyLeft', "COMPLETED!", string.format("COWS SOLD SUCCESSFULLY FOR $%d", reward), "generic_textures", "tick", 4000)
    ResetMission()
    
    -- Clear GPS route when mission is completed
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
    end
    
    TriggerServerEvent("rustling:MissionComplete")
end)






-- Event handler for respawning (if needed)
RegisterNetEvent("rustling:Respawn")
AddEventHandler("rustling:Respawn", function()
    if not missionStarted then
        StartMission()
    end
end)

RegisterNetEvent("rustling:ResetMission")
AddEventHandler("rustling:ResetMission", function()
    if missionStarted then
        ResetMission()
        TriggerEvent('rNotify:NotifyLeft', "Mission Failed", "The rustling mission has timed out.", "generic_textures", "cross", 4000)
    end
end)

