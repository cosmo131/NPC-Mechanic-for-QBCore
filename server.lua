local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('mechanic:server:canAfford', function(source, cb, amount, moneyType)
    local player = QBCore.Functions.GetPlayer(source)

    if not player then
        cb(false)
        return
    end

    local balance = player.Functions.GetMoney(moneyType)
    cb(balance >= amount)
end)

RegisterNetEvent('mechanic:pay', function(amount, moneyType, serviceType)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    if not player then
        return
    end

    if moneyType ~= 'cash' then
        moneyType = 'bank'
    end

    if serviceType ~= 'repair' and serviceType ~= 'fuel' then
        serviceType = 'tow'
    end

    player.Functions.RemoveMoney(moneyType, amount, ('npc-mechanic-%s'):format(serviceType))
end)
