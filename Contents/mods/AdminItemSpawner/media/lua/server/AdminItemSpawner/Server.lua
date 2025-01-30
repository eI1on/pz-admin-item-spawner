local Globals = require("Starlit/Globals");
local Logger = require("AdminItemSpawner/Logger");

local AdminItemSpawner = require("AdminItemSpawner/Shared");
AdminItemSpawner.Server = {};
AdminItemSpawner.Server.ServerCommands = {};

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------

local SPAWN_MODES = {
    LOCAL = "local",
    GLOBAL = "global",
    PLAYER = "player"
}

---@param username string
---@return string|nil
local function getOnlinePlayerByUsername(username)
    local onlinePlayers = getOnlinePlayers();
    if onlinePlayers then
        for i = 0, onlinePlayers:size() - 1 do
            local onlinePlayer = onlinePlayers:get(i);
            if onlinePlayer and onlinePlayer:getUsername() == username then
                return onlinePlayer;
            end
        end
    end
    return nil;
end

---@param items table
---@return string
local function formatItemsList(items)
    local lines = {};
    for itemType, count in pairs(items) do
        if count > 1 then
            table.insert(lines, string.format("%s=%d", itemType, count));
        else
            table.insert(lines, itemType);
        end
    end
    if #lines == 0 then return "N/A"; end
    return table.concat(lines, ";");
end

--------------------------------------------------
-- LOGGING ACTIONS ON SERVER
--------------------------------------------------
function AdminItemSpawner.Server.writeLog(packet)
    writeLog(packet.loggerName, packet.logText);
end

--------------------------------------------------
-- PUSHING UPDATES TO CLIENTS
--------------------------------------------------
function AdminItemSpawner.Server.PushUpdateToAll(args)
    if Globals.isServer then
        sendServerCommand("AdminItemSpawner", "SpawnItems", args);
    end
end

function AdminItemSpawner.Server.PushUpdateToPlayer(player, args)
    if Globals.isServer then
        sendServerCommand(player, "AdminItemSpawner", "SpawnItems", args);
    end
end

--------------------------------------------------
-- SERVER COMMAND HANDLERS
--------------------------------------------------

---@param player IsoPlayer
---@param args table
function AdminItemSpawner.Server.ServerCommands.SpawnItems(player, args)
    if args.spawnMode == SPAWN_MODES.PLAYER and args.targetPlayer then
        local targetPlayerObj = getOnlinePlayerByUsername(args.targetPlayer);
        if targetPlayerObj then
            AdminItemSpawner.Server.PushUpdateToPlayer(targetPlayerObj, args);
        end
    elseif args.spawnMode == SPAWN_MODES.LOCAL or args.spawnMode == SPAWN_MODES.GLOBAL then
        AdminItemSpawner.Server.PushUpdateToAll(args);
    end

    local logText = string.format(
        "[Player: %s | SteamID: %s | Role: %s] Spawned items at (%s,%s,%s) | Radius: %s | Mode: %s | Target: %s | Items: %s",
        tostring(player:getUsername() or "Unknown"),
        tostring(player:getSteamID() or "0"),
        tostring(player:getAccessLevel() or "None"),
        tostring(args.x or "-1"),
        tostring(args.y or "-1"),
        tostring(args.z or "-1"),
        tostring(args.radius or "-1"),
        tostring(args.spawnMode or "N/A"),
        tostring(args.targetPlayer or "N/A"),
        tostring(formatItemsList(args.items or {}))
    );
    AdminItemSpawner.Server.writeLog({ loggerName = "admin", logText = logText });
end

function AdminItemSpawner.Server.onClientCommand(module, command, player, args)
    if module ~= "AdminItemSpawner" then return; end
    if AdminItemSpawner.Server.ServerCommands[command] then
        AdminItemSpawner.Server.ServerCommands[command](player, args);
    end
end

Events.OnClientCommand.Add(AdminItemSpawner.Server.onClientCommand);
