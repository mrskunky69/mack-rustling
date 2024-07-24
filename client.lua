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
local isMissionStarter = false

local function NotifyPlayer(title, message, texture, txd, duration)
    if isMissionStarter then
        TriggerEvent('rNotify:NotifyLeft', title, message, texture or "generic_textures", txd or "tick", duration or 4000)
    end
end

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
        while DoesEntityExist(cow) and not IsEntityDead(cow) and isCowsAttached do
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
    if isMissionStarter then
        local playerPed = PlayerPedId()
        rustlingPlayer = PlayerId()
        
        for _, cow in ipairs(cows) do
            if DoesEntityExist(cow) and not IsEntityDead(cow) then
                Citizen.InvokeNative(0x3AD51CAB001A6108, cow, true)  -- Set animal as being led
                SetBlockingOfNonTemporaryEvents(cow, true)
                TaskFollowToOffsetOfEntity(cow, playerPed, 0.0, -3.0, 0.0, 1.0, -1, 1.0, true)
                
                MakeCowFollow(cow, playerPed)
            end
        end
        
        isCowsAttached = true 
        NotifyPlayer("The cows are now following you", "Lead them to the selling point.")
        TriggerServerEvent("rustling:SetRustlingPlayer", GetPlayerServerId(rustlingPlayer))
        TriggerServerEvent("rustling:NotifyPolice")
    end
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
        NotifyPlayer("Rustling", "Mission started! Defeat the bandits and rustle the cows.")
        TriggerServerEvent("rustling:SetActiveMissionPlayer")
    end
end

RegisterNetEvent("rustling:StartMission")
AddEventHandler("rustling:StartMission", function()
    isMissionStarter = true
    StartMission()
end)

local function ResetMission()
    -- Delete entities
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
    for _, horse in ipairs(horses) do
        if DoesEntityExist(horse) then
            DeleteEntity(horse)
        end
    end

    -- Clear blips
    for _, blip in ipairs(cowBlips) do
        RemoveBlip(blip)
    end

    -- Reset tables
    cows = {}
    bandits = {}
    horses = {}
    cowBlips = {}

    -- Reset flags and variables
    isCowsAttached = false
    missionStarted = false
    rustlingPlayer = nil
    isMissionStarter = false  -- Reset the mission starter flag

    -- Clear GPS route if it was added
    if Config.AddGPSRoute then
        ClearGpsMultiRoute()
    end

    -- Remove any remaining markers or UI elements
    if sellPointMarker then
        RemoveBlip(sellPointMarker)
        sellPointMarker = nil
    end

    -- Reset any timers or intervals
    if resetTimerId then
        clearTimeout(resetTimerId)
        resetTimerId = nil
    end

    -- Clear any remaining tasks for the local player
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)

    -- Reset the camera if it was modified
    RenderScriptCams(false, false, 0, true, true)

    -- Restore the player's original state if necessary
    SetEntityInvincible(playerPed, false)
    SetEntityVisible(playerPed, true)

    -- Notify the player that the mission has been reset
    NotifyPlayer("Mission Reset", "The rustling mission has been reset.")

    -- Trigger a server event to inform about the mission reset
    TriggerServerEvent("rustling:MissionReset")

    
end



Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)  -- Changed to 0 for more responsive checks
        
        if missionStarted and isMissionStarter then
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
                        NotifyPlayer("Cows Attached", "Lead the cows to the selling point.")
                        
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
                -- Existing selling logic
                local sellPointDistance = #(playerCoords - Config.SellNPCLocation)
                
                print("Sell point distance: " .. sellPointDistance)
                
                if sellPointDistance <= Config.SellingRadius then
                    local allCowsNear = true
                    local aliveCowCount = 0
                    for _, cow in ipairs(cows) do
                        if DoesEntityExist(cow) and not IsEntityDead(cow) then
                            local cowCoords = GetEntityCoords(cow)
                            local cowDistance = #(cowCoords - Config.SellNPCLocation)
                            if cowDistance > Config.CowSellDistance then
                                allCowsNear = false
                                print("Cow too far: " .. cowDistance)
                                break
                            end
                            aliveCowCount = aliveCowCount + 1
                        end
                    end

                    print("All cows near: " .. tostring(allCowsNear))
                    print("Alive cow count: " .. aliveCowCount)

                    if allCowsNear and aliveCowCount > 0 then
                        Draw3DText(Config.SellNPCLocation.x, Config.SellNPCLocation.y, Config.SellNPCLocation.z + 1.0, 
                            "Selling " .. aliveCowCount .. " cows...")
                        
                        print("Attempting to sell cows")
                        TriggerServerEvent("rustling:SellCows", aliveCowCount)
                        print("Sell event triggered")
                        
                        Citizen.Wait(1000)
                        
                        ResetMission()
                        
                        break
                    else
                        if not allCowsNear then
                            NotifyPlayer("Cows too far", "Some cows are too far from the sell point.")
                        elseif aliveCowCount == 0 then
                            NotifyPlayer("No cows", "There are no alive cows to sell.")
                        else
                            NotifyPlayer("Almost there!", "Make sure all cows are close to the sell point.")
                        end
                    end
                else
                    NotifyPlayer("Get closer", "Move closer to the selling point.")
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
    NotifyPlayer("COMPLETED!", string.format("COWS SOLD SUCCESSFULLY FOR $%d", reward))
    ResetMission()
    
    -- Clear GPS route if it was added
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

