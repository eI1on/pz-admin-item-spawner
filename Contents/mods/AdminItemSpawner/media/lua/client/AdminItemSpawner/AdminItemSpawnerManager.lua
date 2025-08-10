local Globals = require("Starlit/Globals");
local Logger = require("AdminItemSpawner/Logger");

local AdminItemSpawner = require("AdminItemSpawner/Shared");

AdminItemSpawnerPanel = ISPanel:derive("AdminItemSpawnerPanel");
AdminItemSpawnerPanel.instance = nil;

local CONST = {
    PADDING = 20,
    ELEMENT_HEIGHT = 25,
    MODAL_WIDTH = 300,
    MODAL_HEIGHT = 600,
    LABEL_WIDTH = 80,
    ENTRY_WIDTH = 200,
    COORD_ENTRY_WIDTH = 60,
    SECTION_SPACING = 15,
    ITEM_SPACING = 10,
    BUTTON_WIDTH = 100,
    BUTTON_HEIGHT = 30,
    PLAYER_LIST_HEIGHT = 100,
    ITEMS_LIST_HEIGHT = 150,
    FONT = {
        SMALL = UIFont.Small,
        MEDIUM = UIFont.Medium,
        LARGE = UIFont.Large
    },
    COLORS = {
        BORDER = { r = 0.4, g = 0.4, b = 0.4, a = 1 },
        BACKGROUND = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 },
        TEXT = { r = 1, g = 1, b = 1, a = 1 },
        LIST_HIGHLIGHT = { r = 0.3, g = 0.3, b = 0.3, a = 1 },
        PLAYER_SECTION = { r = 0.2, g = 0.8, b = 0.4, a = 1 },
        PLAYER_SECTION_INACTIVE = { r = 0.5, g = 0.1, b = 0.1, a = 1 }
    },
    SPAWN_MODES = {
        LOCAL = "local",
        GLOBAL = "global",
        PLAYER = "player"
    }
};

function AdminItemSpawnerPanel:new(x, y, width, height, playerObj, square)
    local o = ISPanel:new(x, y, CONST.MODAL_WIDTH, CONST.MODAL_HEIGHT);
    setmetatable(o, self);
    self.__index = self;

    o.borderColor = CONST.COLORS.BORDER;
    o.backgroundColor = CONST.COLORS.BACKGROUND;
    o.width = CONST.MODAL_WIDTH;
    o.height = CONST.MODAL_HEIGHT;
    o.playerObj = playerObj;
    o.moveWithMouse = true;
    o.selectedPlayer = nil;
    o.spawnMode = CONST.SPAWN_MODES.LOCAL;

    o.selectX = square:getX();
    o.selectY = square:getY();
    o.selectZ = square:getZ();
    o:addMarker(square, 1);

    o.scoreboard = nil;

    return o;
end

function AdminItemSpawnerPanel:createSpawnModeSection(y)
    self.spawnModeGroup = ISRadioButtons:new(CONST.PADDING, y, CONST.LABEL_WIDTH * 2, CONST.ELEMENT_HEIGHT, self,
        self.onSpawnModeChanged);
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnLocal"));
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnGlobal"));
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnToPlayer"));
    self.spawnModeGroup.selectedValue = CONST.SPAWN_MODES.LOCAL;
    self.spawnModeGroup.tooltip = getText("Tooltip_AIS_SpawnModeGroup");
    self:addChild(self.spawnModeGroup);

    return self.spawnModeGroup:getBottom() + CONST.SECTION_SPACING;
end

function AdminItemSpawnerPanel:createPlayerList(y)
    self.playerListLabel1 = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_PlayerList1"),
        CONST.COLORS.PLAYER_SECTION_INACTIVE.r,
        CONST.COLORS.PLAYER_SECTION_INACTIVE.g,
        CONST.COLORS.PLAYER_SECTION_INACTIVE.b,
        1, CONST.FONT.MEDIUM, true);
    self:addChild(self.playerListLabel1);
    y = self.playerListLabel1:getBottom();

    self.playerListLabel2 = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_PlayerList2"),
        CONST.COLORS.PLAYER_SECTION_INACTIVE.r,
        CONST.COLORS.PLAYER_SECTION_INACTIVE.g,
        CONST.COLORS.PLAYER_SECTION_INACTIVE.b,
        1, CONST.FONT.MEDIUM, true);
    self:addChild(self.playerListLabel2);
    y = self.playerListLabel2:getBottom();

    self.playerList = ISScrollingListBox:new(
        CONST.PADDING, y,
        self.width - (CONST.PADDING * 2),
        CONST.PLAYER_LIST_HEIGHT
    );
    self.playerList:initialise();
    self.playerList:instantiate();
    self.playerList.itemheight = CONST.ELEMENT_HEIGHT;
    self.playerList.selected = 0;
    self.playerList.joypadParent = self;
    self.playerList.font = CONST.FONT.SMALL;
    self.playerList.doDrawItem = self.drawPlayerListItem;
    self.playerList.drawBorder = true;
    self.playerList.borderColor = CONST.COLORS.PLAYER_SECTION_INACTIVE;
    self:addChild(self.playerList);

    self:populatePlayerList();
    return self.playerList:getBottom() + CONST.SECTION_SPACING;
end

function AdminItemSpawnerPanel:populatePlayerList()
    self.playerList:clear();
    if Globals.isSingleplayer then
        local item = {};
        local name = self.playerObj:getDisplayName();
        item.username = self.playerObj:getUsername();
        item.displayName = name;
        self.playerList:addItem(name, item);
    elseif Globals.isClient then
        if not self.scoreboard then return end
        for i = 0, self.scoreboard.usernames:size() - 1 do
            local username = self.scoreboard.usernames:get(i);
            local displayName = self.scoreboard.displayNames:get(i);
            if username ~= self.playerObj:getUsername() then
                local item = {};
                local name = displayName;
                item.username = username;
                item.displayName = displayName;
                local item0 = self.playerList:addItem(name, item);
                if username ~= displayName then
                    item0.tooltip = username;
                end
            end
        end
    end
end

function AdminItemSpawnerPanel:drawPlayerListItem(y, item, alt)
    local highlight = self.selected == item.index;
    local backgroundColor = highlight and CONST.COLORS.LIST_HIGHLIGHT or
        (alt and CONST.COLORS.BACKGROUND or { r = 0.2, g = 0.2, b = 0.2, a = 0.85 });

    self:drawRect(0, y, self:getWidth(), self.itemheight - 1, backgroundColor.a, backgroundColor.r, backgroundColor.g,
        backgroundColor.b);
    self:drawText(item.text, 4, y + 2, CONST.COLORS.TEXT.r, CONST.COLORS.TEXT.g, CONST.COLORS.TEXT.b, CONST.COLORS.TEXT
        .a, self.font);

    return y + self.itemheight;
end

function AdminItemSpawnerPanel:initialise()
    ISPanel.initialise(self);
    local y = CONST.PADDING;

    self.titleLabel = ISLabel:new(
        (self.width - getTextManager():MeasureStringX(CONST.FONT.LARGE, getText("IGUI_AIS_AdminItemSpawner"))) / 2,
        y, CONST.ELEMENT_HEIGHT, getText("IGUI_AIS_AdminItemSpawner"),
        1, 1, 1, 1, CONST.FONT.LARGE, true
    );
    self:addChild(self.titleLabel);
    y = self.titleLabel:getBottom() + CONST.SECTION_SPACING;

    y = self:createCoordinatesSection(y);

    y = self:createSpawnModeSection(y);

    y = self:createPlayerList(y);

    y = self:createRadiusSection(y);

    y = self:createItemsSection(y);

    y = self:createButtonsSection(y);

    self:setHeight(y + CONST.PADDING);

    if Globals.isClient then
        scoreboardUpdate();
    end
end

function AdminItemSpawnerPanel:createCoordinatesSection(y)
    self.coordLabel = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_Coordinates"), 1, 1, 1, 1, CONST.FONT.MEDIUM, true);
    self:addChild(self.coordLabel);

    self.pickSquareButton = ISButton:new(
        self.width - (CONST.BUTTON_WIDTH + CONST.PADDING), y,
        CONST.BUTTON_WIDTH, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_PickSquare"),
        self, AdminItemSpawnerPanel.onSelectSquare
    );
    self:addChild(self.pickSquareButton);

    y = self.coordLabel:getBottom();

    self.coordTextLabel = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        string.format("X: %d, Y: %d, Z: %d", self.selectX, self.selectY, self.selectZ),
        1, 1, 1, 1, CONST.FONT.MEDIUM, true);
    self:addChild(self.coordTextLabel);


    return self.coordTextLabel:getBottom() + CONST.SECTION_SPACING;
end

function AdminItemSpawnerPanel:createRadiusSection(y)
    self.radiusLabel = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_Radius"), 1, 1, 1, 1, CONST.FONT.MEDIUM, true);
    self:addChild(self.radiusLabel);

    self.radiusEntryBox = ISTextEntryBox:new("1", self.radiusLabel:getRight() + CONST.ITEM_SPACING, y, 100,
        CONST.ELEMENT_HEIGHT);
    self.radiusEntryBox:initialise();
    self.radiusEntryBox:instantiate();
    self.radiusEntryBox:setOnlyNumbers(true);
    self.radiusEntryBox:setEditable(true);
    self:addChild(self.radiusEntryBox);

    return self.radiusEntryBox:getBottom() + CONST.SECTION_SPACING;
end

function AdminItemSpawnerPanel:createItemsSection(y)
    self.itemsLabel = ISLabel:new(CONST.PADDING, y, CONST.ELEMENT_HEIGHT,
        getText("IGUI_AIS_ItemsList"), 1, 1, 1, 1, CONST.FONT.MEDIUM, true);
    self:addChild(self.itemsLabel);
    y = y + CONST.ELEMENT_HEIGHT;

    self.itemsEntry = ISTextEntryBox:new("", CONST.PADDING, y,
        self.width - (CONST.PADDING * 2), CONST.ITEMS_LIST_HEIGHT);
    self.itemsEntry:initialise();
    self.itemsEntry:instantiate();
    self.itemsEntry:setMultipleLine(true);
    self.itemsEntry:setMaxLines(999);
    self.itemsEntry:setText("");
    self:addChild(self.itemsEntry);

    return self.itemsEntry:getBottom() + CONST.SECTION_SPACING;
end

function AdminItemSpawnerPanel:createButtonsSection(y)
    self.spawnBtn = ISButton:new(
        CONST.PADDING, y,
        CONST.BUTTON_WIDTH, CONST.BUTTON_HEIGHT,
        getText("IGUI_AIS_Spawn"),
        self, AdminItemSpawnerPanel.onClick
    );
    self.spawnBtn.internal = "SPAWN";
    self:addChild(self.spawnBtn);

    self.cancelBtn = ISButton:new(
        self.width - CONST.BUTTON_WIDTH - CONST.PADDING, y,
        CONST.BUTTON_WIDTH, CONST.BUTTON_HEIGHT,
        getText("IGUI_AIS_Cancel"),
        self, AdminItemSpawnerPanel.onClick
    );
    self.cancelBtn.internal = "CANCEL";
    self:addChild(self.cancelBtn);

    return y + CONST.BUTTON_HEIGHT;
end

function AdminItemSpawnerPanel:onSpawnModeChanged(buttons, index)
    local mode = (index == 1 and CONST.SPAWN_MODES.LOCAL) or (index == 2 and CONST.SPAWN_MODES.GLOBAL) or
        (index == 3 and CONST.SPAWN_MODES.PLAYER)
    self.spawnMode = mode;
    local isPlayerMode = (mode == CONST.SPAWN_MODES.PLAYER);

    local playerSelectionColor = {
        r = isPlayerMode and CONST.COLORS.PLAYER_SECTION.r or CONST.COLORS.PLAYER_SECTION_INACTIVE.r,
        g = isPlayerMode and CONST.COLORS.PLAYER_SECTION.g or CONST.COLORS.PLAYER_SECTION_INACTIVE.g,
        b = isPlayerMode and CONST.COLORS.PLAYER_SECTION.b or CONST.COLORS.PLAYER_SECTION_INACTIVE.b,
        a = 1.0
    };
    self.playerListLabel1:setColor(playerSelectionColor.r, playerSelectionColor.g, playerSelectionColor.b);
    self.playerListLabel2:setColor(playerSelectionColor.r, playerSelectionColor.g, playerSelectionColor.b);
    self.playerList.borderColor = playerSelectionColor;

    self.radiusEntryBox:setEditable(mode == CONST.SPAWN_MODES.LOCAL);

    if isPlayerMode then
        self:populatePlayerList();
    end
end

function AdminItemSpawnerPanel:parseItemsList(text)
    local items = {};
    for line in text:gmatch("[^\r\n]+") do
        for entry in line:gmatch("[^;]+") do
            entry = entry:trim();
            if entry ~= "" then
                local itemType, count = entry:match("([^=]+)=(%d+)");
                if itemType then
                    itemType = itemType:trim();
                    count = tonumber(count);
                    items[itemType] = (items[itemType] or 0) + count;
                else
                    itemType = entry;
                    items[itemType] = (items[itemType] or 0) + 1;
                end
            end
        end
    end
    return items;
end

function AdminItemSpawnerPanel:onClick(button)
    if button.internal == "SPAWN" then
        local items = self:parseItemsList(self.itemsEntry:getText());
        local args = {
            steamID = getCurrentUserSteamID(),
            items = items,
            x = self.selectX,
            y = self.selectY,
            z = self.selectZ,
            radius = tonumber(self.radiusEntryBox:getText()) or 1,
            spawnMode = self.spawnMode,
            targetPlayer = self.playerList.selected > 0 and
                self.playerList.items[self.playerList.selected].item and
                self.playerList.items[self.playerList.selected].item.username or nil,
        };
        if Globals.isClient then
            sendClientCommand(self.playerObj, "AdminItemSpawner", "SpawnItems", args);
        else
            AdminItemSpawner.Client.SpawnItems(self.playerObj, args);
        end
    elseif button.internal == "CANCEL" then
        self:close();
    end
end

function AdminItemSpawnerPanel:prerender()
    ISPanel.prerender(self);

    local radius = self:getRadius() + 1;
    if self.marker and (self.marker:getSize() ~= radius) then
        self.marker:setSize(radius);
    end
end

function AdminItemSpawnerPanel:onGlobalToggled(index, selected)
    self.isGlobal = selected;
    self.radiusEntryBox:setEditable(not selected);
end

function AdminItemSpawnerPanel:addMarker(square, radius)
    self.marker = getWorldMarkers():addGridSquareMarker(square, 1.0, 0.0, 0.0, true, radius);
    self.marker:setScaleCircleTexture(true);
end

function AdminItemSpawnerPanel:onSelectSquare()
    self.cursor = ISSelectCursor:new(self.playerObj, self, self.onSquareSelected);
    getCell():setDrag(self.cursor, self.playerObj:getPlayerNum());
end

function AdminItemSpawnerPanel:onSquareSelected(square)
    self:removeMarker();
    self.selectX = square:getX();
    self.selectY = square:getY();
    self.selectZ = square:getZ();
    self.coordTextLabel:setName(string.format("X: %d, Y: %d, Z: %d", self.selectX, self.selectY, self.selectZ));
    self:addMarker(square, self:getRadius() + 1);
end

function AdminItemSpawnerPanel:getRadius()
    local radius = self.radiusEntryBox:getInternalText()
    return (tonumber(radius) or 1) - 1;
end

function AdminItemSpawnerPanel:removeMarker()
    if self.marker then
        self.marker:remove();
        self.marker = nil;
    end
    if self.arrow then
        self.arrow:remove();
        self.arrow = nil;
    end
end

function AdminItemSpawnerPanel:close()
    self:removeMarker();
    self:setVisible(false);
    self:removeFromUIManager();
    AdminItemSpawnerPanel.instance = nil;
end

function AdminItemSpawnerPanel.onScoreboardUpdate(usernames, displayNames, steamIDs)
    if AdminItemSpawnerPanel.instance then
        AdminItemSpawnerPanel.instance.scoreboard = {};
        AdminItemSpawnerPanel.instance.scoreboard.usernames = usernames;
        AdminItemSpawnerPanel.instance.scoreboard.displayNames = displayNames;
        AdminItemSpawnerPanel.instance.scoreboard.steamIDs = steamIDs;
        AdminItemSpawnerPanel.instance:populatePlayerList();
    end
end

AdminItemSpawnerPanel.OnMiniScoreboardUpdate = function()
    if ISMiniScoreboardUI.instance then
        scoreboardUpdate();
    end
end

Events.OnScoreboardUpdate.Add(AdminItemSpawnerPanel.onScoreboardUpdate);
Events.OnMiniScoreboardUpdate.Add(AdminItemSpawnerPanel.OnMiniScoreboardUpdate);

function AdminItemSpawnerPanel.openPanel()
    local x = getCore():getScreenWidth() / 1.5;
    local y = getCore():getScreenHeight() / 6;
    if AdminItemSpawnerPanel.instance == nil then
        local window = AdminItemSpawnerPanel:new(x, y, CONST.WINDOW_WIDTH, CONST.WINDOW_HEIGHT, getPlayer(),
            getPlayer():getSquare());
        window:initialise();
        window:addToUIManager();
        AdminItemSpawnerPanel.instance = window;
    else
        AdminItemSpawnerPanel.instance:close();
    end
end

local ISDebugMenu_setupButtons = ISDebugMenu.setupButtons;
---@diagnostic disable-next-line: duplicate-set-field
function ISDebugMenu:setupButtons()
    self:addButtonInfo(getText("IGUI_AIS_AdminItemSpawner"), function() AdminItemSpawnerPanel.openPanel() end,
        "MAIN");
    ISDebugMenu_setupButtons(self);
end

local ISAdminPanelUI_create = ISAdminPanelUI.create;
---@diagnostic disable-next-line: duplicate-set-field
function ISAdminPanelUI:create()
    ISAdminPanelUI_create(self);
    local fontHeight = getTextManager():getFontHeight(UIFont.Small);
    local btnWid = 150;
    local btnHgt = math.max(25, fontHeight + 3 * 2);
    local btnGapY = 5;

    local lastButton = self.children[self.IDMax - 1];
    lastButton = lastButton.internal == "CANCEL" and self.children[self.IDMax - 2] or lastButton;

    self.showAdminItemSpawner = ISButton:new(lastButton.x, lastButton.y + btnHgt + btnGapY, btnWid, btnHgt,
        getText("IGUI_AIS_AdminItemSpawner"), self, AdminItemSpawnerPanel.openPanel);
    self.showAdminItemSpawner.internal = "";
    self.showAdminItemSpawnerPanel:initialise();
    self.showAdminItemSpawnerPanel:instantiate();
    self.showAdminItemSpawner.borderColor = self.buttonBorderColor;
    self:addChild(self.showAdminItemSpawner);
end

local function onFillWorldObjectContextMenu(player, context, worldobjects)
    if not player then return; end
    local hasAccess = false;
    if Globals.isSingleplayer then
        hasAccess = true;
    elseif Globals.isClient then
        -- hasAccess = isAdmin();
    end

    if Globals.isDebug then hasAccess = true; end

    if hasAccess then
        context:addOptionOnTop(
            getText("IGUI_AIS_AdminItemSpawner"), worldobjects,
            function()
                AdminItemSpawnerPanel.openPanel();
            end
        );
    end
end

Events.OnFillWorldObjectContextMenu.Remove(onFillWorldObjectContextMenu);
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu);
