local RSGCore = exports['rsg-core']:GetCoreObject()
local missionActive = false
local rustlingPlayer = nil
local resetTimerId = nil
local missionStarterPlayer = nil

RegisterServerEvent("rustling:SetActiveMissionPlayer")
AddEventHandler("rustling:SetActiveMissionPlayer", function()
    rustlingPlayer = source
end)

RegisterServerEvent("rustling:RequestMissionStart")
AddEventHandler("rustling:RequestMissionStart", function()
    if not missionActive then
        missionActive = true
        missionStarterPlayer = source
        print("Mission activated by player " .. missionStarterPlayer)
        TriggerClientEvent("rustling:StartMission", missionStarterPlayer) -- Only trigger for the starter
        TriggerEvent("rustling:StartMission") -- Trigger the reset timer
    else
        TriggerClientEvent('RSGCore:Notify', source, "A rustling mission is already in progress.", "error")
    end
end)

RegisterServerEvent("rustling:MissionComplete")
AddEventHandler("rustling:MissionComplete", function()
    missionActive = false
    rustlingPlayer = nil
    if resetTimerId then
        clearTimeout(resetTimerId)
        resetTimerId = nil
    end
    print("Mission completed and reset timer cleared")
end)



-- Event to notify police
RegisterServerEvent("rustling:NotifyPolice")
AddEventHandler("rustling:NotifyPolice", function()
    local Players = RSGCore.Functions.GetPlayers()
    for _, playerId in ipairs(Players) do
        local Player = RSGCore.Functions.GetPlayer(playerId)
        if Player.PlayerData.job.type == Config.PoliceJobName and playerId ~= missionStarterPlayer then
            TriggerClientEvent('rNotify:ShowObjective', playerId, "Rustlers are in the Area", 4000)
        end
    end
end)

-- Remove the ResetMission function and the SetTimeout call

RegisterServerEvent("rustling:SellCows")
AddEventHandler("rustling:SellCows", function(cowCount)
    local src = source
    if src ~= rustlingPlayer then
        TriggerClientEvent('RSGCore:Notify', src, "You didn't rustle these cows!", "error")
        return
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        local reward = cowCount * Config.PricePerCow
        Player.Functions.AddMoney("cash", reward, "Sold rustled cows")
        TriggerClientEvent("rustling:SaleComplete", src, reward)
        missionActive = false
        rustlingPlayer = nil  -- Reset after successful sale
    end
end)


RegisterServerEvent("rustling:SetRustlingPlayer")
AddEventHandler("rustling:SetRustlingPlayer", function(playerId)
    rustlingPlayer = playerId
end)

RegisterServerEvent("rustling:ResetRustlingPlayer")
AddEventHandler("rustling:ResetRustlingPlayer", function()
    rustlingPlayer = nil
end)

RegisterServerEvent("rustling:StartMission")
AddEventHandler("rustling:StartMission", function()
    if resetTimerId then
        clearTimeout(resetTimerId)
    end
    resetTimerId = SetTimeout(Config.MissionResetTime * 60000, function()
        if missionActive then
            missionActive = false
            rustlingPlayer = nil
            TriggerClientEvent("rustling:ResetMission", -1)
        end
        resetTimerId = nil
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    print('The resource ' .. resourceName .. ' has been started.')
    missionActive = false
    rustlingPlayer = nil
    TriggerClientEvent("rustling:ResetMission", -1)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    print('The resource ' .. resourceName .. ' has been stopped.')
    TriggerClientEvent("rustling:ResetMission", -1)
end)