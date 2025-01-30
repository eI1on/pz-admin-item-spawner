local AdminItemSpawner = require("AdminItemSpawner/Shared");

AdminItemSpawner.Client = {};
AdminItemSpawner.Client.ClientCommands = {};

---@param playerObj IsoPlayer
---@param items table
local function spawnItemsOnPlayer(playerObj, items)
    local itemsReceivedInfo = {};
    for itemType, count in pairs(items) do
        local item = ScriptManager.instance:getItem(itemType);
        if item then
            for i = 1, count do
                playerObj:getInventory():AddItem(itemType);
            end
            local itemDisplayName = item:getDisplayName();
            table.insert(itemsReceivedInfo, string.format("%sx %s", tostring(count), tostring(itemDisplayName)));
        end
    end
    if #itemsReceivedInfo >= 0 then
        playerObj:Say(getText("ContextMenu_AIS_IReceived") .. table.concat(itemsReceivedInfo, ", "));
    end
end

---@param playerObj IsoPlayer
---@param args table
function AdminItemSpawner.Client.SpawnItems(playerObj, args)
    local function isWithinRadius(x, y, z, centerX, centerY, centerZ, radius)
        local dx, dy, dz = x - centerX, y - centerY, z - centerZ;
        return (dx * dx + dy * dy + dz * dz) <= (radius * radius);
    end

    local spawnMode = args.spawnMode;
    local items = args.items or {};

    if spawnMode == "local" then
        if isWithinRadius(playerObj:getX(), playerObj:getY(), playerObj:getZ(), args.x, args.y, args.z, args.radius) then
            spawnItemsOnPlayer(playerObj, items);
        end
    elseif spawnMode == "global" then
        spawnItemsOnPlayer(playerObj, items);
    elseif spawnMode == "player" then
        local targetPlayer = args.targetPlayer;
        if targetPlayer and playerObj:getUsername() == targetPlayer then
            spawnItemsOnPlayer(playerObj, items);
        end
    end
end

---@param args table
function AdminItemSpawner.Client.ClientCommands.SpawnItems(args)
    AdminItemSpawner.Client.SpawnItems(getPlayer(), args);
end

function AdminItemSpawner.Client.ClientCommands.onServerCommand(module, command, args)
    if module ~= "AdminItemSpawner" then return; end
    if AdminItemSpawner.Client.ClientCommands[command] then
        AdminItemSpawner.Client.ClientCommands[command](args);
    end
end

Events.OnServerCommand.Add(AdminItemSpawner.Client.ClientCommands.onServerCommand);
