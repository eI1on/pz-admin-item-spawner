require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"

local Globals                  = require("Starlit/Globals")
local Logger                   = require("AdminItemSpawner/Logger")
local AdminItemSpawner         = require("AdminItemSpawner/Shared")
local Theme                    = require("ElyonLib/UI/Theme/Theme")

AdminItemSpawnerPanel          = ISCollapsableWindow:derive("AdminItemSpawnerPanel")
AdminItemSpawnerPanel.instance = nil

local FONT_HGT_SMALL           = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM          = getTextManager():getFontHeight(UIFont.Medium)

local C                        = {
    DEFAULT_W     = 480,
    DEFAULT_H     = 580,
    MIN_W         = 420,
    MIN_H         = 480,
    PAD           = 12,
    GAP           = 8,
    BUTTON_H      = 26,
    FIELD_H       = 24,
    ROW_H         = 24,
    PLAYER_LIST_H = 100,
    ITEMS_MIN_H   = 80,
    SPAWN_MODES   = {
        LOCAL  = "local",
        GLOBAL = "global",
        PLAYER = "player",
    },
    COLORS        = (function()
        local colors                   = Theme.standardColors()
        local T                        = Theme.colors
        colors.PLAYER_SECTION          = Theme.copy(T.success)
        colors.PLAYER_SECTION_INACTIVE = Theme.copy(T.textDim)
        colors.LIST_HIGHLIGHT          = Theme.copy(T.selected)
        return colors
    end)(),
}

local function applyButtonStyle(btn, variant)
    Theme.applyButtonStyle(btn, variant)
end

local function applyFieldStyle(entry)
    Theme.applyFieldStyle(entry)
end

local function sectionLabel(panel, text)
    local lbl = ISLabel:new(0, 0, FONT_HGT_MEDIUM, text, 1, 1, 1, 1, UIFont.Medium, true)
    lbl:initialise()
    lbl:instantiate()
    panel:addChild(lbl)
    return lbl
end

local function fieldLabel(panel, text)
    local lbl = ISLabel:new(0, 0, FONT_HGT_SMALL, text,
        C.COLORS.MUTED.r, C.COLORS.MUTED.g, C.COLORS.MUTED.b, 1, UIFont.Small, true)
    lbl:initialise()
    lbl:instantiate()
    panel:addChild(lbl)
    return lbl
end

local function colorLabel(panel, text, color)
    local col = color or C.COLORS.MUTED
    local lbl = ISLabel:new(0, 0, FONT_HGT_SMALL, text, col.r, col.g, col.b, 1, UIFont.Small, true)
    lbl:initialise()
    lbl:instantiate()
    panel:addChild(lbl)
    return lbl
end

local function makeButton(panel, text, internal, variant, handler)
    local btn = ISButton:new(0, 0, 80, C.BUTTON_H, text, panel, handler)
    btn.internal = internal
    btn:initialise()
    btn:instantiate()
    applyButtonStyle(btn, variant)
    panel:addChild(btn)
    return btn
end

local function makeEntry(panel, text, numbersOnly, multiline)
    local entry = ISTextEntryBox:new(text or "", 0, 0, 80, C.FIELD_H)
    entry:initialise()
    entry:instantiate()
    if numbersOnly then entry:setOnlyNumbers(true) end
    if multiline then
        entry:setMultipleLine(true)
        entry:setMaxLines(999)
    end
    applyFieldStyle(entry)
    panel:addChild(entry)
    return entry
end

local function makeList(panel, drawFn, itemH)
    local list = ISScrollingListBox:new(0, 0, 80, 60)
    list:initialise()
    list:instantiate()
    list.itemheight = itemH or C.ROW_H
    list.font = UIFont.Small
    list.drawBorder = true
    list.selected = 0
    list.joypadParent = panel
    list.doDrawItem = drawFn
    Theme.applyListStyle(list)
    list.drawBorder = true
    panel:addChild(list)
    return list
end

local function setBounds(ctrl, x, y, w, h)
    if not ctrl then return end
    ctrl:setX(x)
    ctrl:setY(y)
    ctrl:setWidth(w)
    ctrl:setHeight(h)
end

function AdminItemSpawnerPanel:new(x, y, playerObj, square)
    local o = ISCollapsableWindow.new(self, x, y, C.DEFAULT_W, C.DEFAULT_H)
    setmetatable(o, self)
    self.__index      = self

    o.playerObj       = playerObj
    o.spawnMode       = C.SPAWN_MODES.LOCAL
    o.selectX         = square:getX()
    o.selectY         = square:getY()
    o.selectZ         = square:getZ()
    o.scoreboard      = nil
    o.layoutDirty     = true
    o.lastLayoutW     = 0
    o.lastLayoutH     = 0

    o.backgroundColor = Theme.copy(Theme.colors.background)
    o.borderColor     = Theme.copy(Theme.colors.border)
    o.resizable       = true
    o.minimumWidth    = C.MIN_W
    o.minimumHeight   = C.MIN_H

    o:addMarker(square, 1)
    return o
end

function AdminItemSpawnerPanel:initialise()
    ISCollapsableWindow.initialise(self)
    self.title = getText("IGUI_AIS_AdminItemSpawner")
end

function AdminItemSpawnerPanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)

    self.lblCoordTitle = sectionLabel(self, getText("IGUI_AIS_Coordinates"))
    self.lblCoordValue = fieldLabel(self, "X: 0, Y: 0, Z: 0")
    self.btnPickSquare = makeButton(self, getText("IGUI_AIS_PickSquare"), "PICK_SQUARE", nil,
        AdminItemSpawnerPanel.onButtonClick)

    self.lblSpawnMode = sectionLabel(self, getText("IGUI_AIS_SpawnMode") or "Spawn Mode")
    self.spawnModeGroup = ISRadioButtons:new(0, 0, 300, C.ROW_H, self,
        AdminItemSpawnerPanel.onSpawnModeChanged)
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnLocal"))
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnGlobal"))
    self.spawnModeGroup:addOption(getText("IGUI_AIS_SpawnToPlayer"))
    self.spawnModeGroup.selectedValue = C.SPAWN_MODES.LOCAL
    self.spawnModeGroup.tooltip = getText("Tooltip_AIS_SpawnModeGroup")
    self:addChild(self.spawnModeGroup)

    self.lblPlayerTitle1        = colorLabel(self, getText("IGUI_AIS_PlayerList1"), C.COLORS.PLAYER_SECTION_INACTIVE)
    self.lblPlayerTitle2        = colorLabel(self, getText("IGUI_AIS_PlayerList2"), C.COLORS.PLAYER_SECTION_INACTIVE)
    self.playerList             = makeList(self, AdminItemSpawnerPanel.drawPlayerListItem, C.ROW_H)
    self.playerList.borderColor = Theme.copy(C.COLORS.PLAYER_SECTION_INACTIVE)

    self.lblRadius              = sectionLabel(self, getText("IGUI_AIS_Radius"))
    self.entryRadius            = makeEntry(self, "1", true, false)

    self.lblItems               = sectionLabel(self, getText("IGUI_AIS_ItemsList"))
    self.entryItems             = makeEntry(self, "", false, true)
    self.entryItems.tooltip = getText("Tooltip_AIS_ItemsList")

    self.btnSpawn               = makeButton(self, getText("IGUI_AIS_Spawn"), "SPAWN", "primary",
        AdminItemSpawnerPanel.onButtonClick)
    self.btnCancel              = makeButton(self, getText("IGUI_AIS_Cancel"), "CANCEL", "danger",
        AdminItemSpawnerPanel.onButtonClick)

    self:updateCoordLabel()
    self:populatePlayerList()

    if Globals.isClient then
        scoreboardUpdate()
    end

    self:layoutChildren()
end

function AdminItemSpawnerPanel:layoutChildren()
    if not self.lblCoordTitle then return end
    if self.isCollapsed then return end

    local w = math.max(self.width, C.MIN_W)
    local h = math.max(self.height, C.MIN_H)
    if self.width ~= w then self:setWidth(w) end
    if self.height ~= h then self:setHeight(h) end

    self.layoutDirty = false
    self.lastLayoutW = w
    self.lastLayoutH = h

    local pad        = C.PAD
    local gap        = C.GAP
    local btnH       = C.BUTTON_H
    local fieldH     = C.FIELD_H
    local cw         = w - pad * 2 -- content width
    local titleH     = self:titleBarHeight()
    local resizeH    = self.resizable and self:resizeWidgetHeight() or 0

    local y          = titleH + gap

    local pickW      = math.min(120, math.floor(cw * 0.30))
    setBounds(self.lblCoordTitle, pad, y, cw - pickW - gap, FONT_HGT_MEDIUM)
    setBounds(self.btnPickSquare, pad + cw - pickW, y, pickW, btnH)
    y = y + FONT_HGT_MEDIUM + 4
    setBounds(self.lblCoordValue, pad, y, cw, FONT_HGT_SMALL)
    self.lblCoordValue.originalX = pad
    y = y + FONT_HGT_SMALL + gap + 4

    self.divCoord = y
    y = y + gap

    setBounds(self.lblSpawnMode, pad, y, cw, FONT_HGT_MEDIUM)
    y = y + FONT_HGT_MEDIUM + 4
    self.spawnModeGroup:setX(pad)
    self.spawnModeGroup:setY(y)
    self.spawnModeGroup:setWidth(cw)
    y = y + self.spawnModeGroup:getHeight() + gap + 4

    self.divSpawnMode = y
    y = y + gap

    setBounds(self.lblPlayerTitle1, pad, y, cw, FONT_HGT_SMALL)
    y = y + FONT_HGT_SMALL + 2
    setBounds(self.lblPlayerTitle2, pad, y, cw, FONT_HGT_SMALL)
    y = y + FONT_HGT_SMALL + 4
    setBounds(self.playerList, pad, y, cw, C.PLAYER_LIST_H)
    y = y + C.PLAYER_LIST_H + gap + 4

    self.divPlayer = y
    y = y + gap

    local radiusLabelW = math.min(120,
        getTextManager():MeasureStringX(UIFont.Medium, getText("IGUI_AIS_Radius")) + 8)
    local radiusEntryW = math.min(80, cw - radiusLabelW - gap)
    setBounds(self.lblRadius, pad, y, radiusLabelW, FONT_HGT_MEDIUM)
    setBounds(self.entryRadius, pad + radiusLabelW + gap, y, radiusEntryW, fieldH)
    y               = y + math.max(FONT_HGT_MEDIUM, fieldH) + gap + 4

    self.divRadius  = y
    y               = y + gap

    local footerY   = h - resizeH - pad - btnH
    local itemsLblY = y
    y               = y + FONT_HGT_MEDIUM + 4
    local itemsH    = math.max(32, footerY - gap - y)
    setBounds(self.lblItems, pad, itemsLblY, cw, FONT_HGT_MEDIUM)
    setBounds(self.entryItems, pad, y, cw, itemsH)

    local btnW = math.min(110, math.floor(cw * 0.35))
    setBounds(self.btnSpawn, pad, footerY, btnW, btnH)
    setBounds(self.btnCancel, w - pad - btnW, footerY, btnW, btnH)
end

function AdminItemSpawnerPanel:onResize()
    self.layoutDirty = true
    self:layoutChildren()
end

function AdminItemSpawnerPanel:prerender()
    ISCollapsableWindow.prerender(self)
    if self.layoutDirty or self.lastLayoutW ~= self.width or self.lastLayoutH ~= self.height then
        self:layoutChildren()
    end
    local radius = self:getRadius() + 1
    if self.marker and (self.marker:getSize() ~= radius) then
        self.marker:setSize(radius)
    end
end

function AdminItemSpawnerPanel:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then return end
    local T = Theme.colors
    local lx = C.PAD
    local lw = self.width - C.PAD * 2
    for _, dy in ipairs({ self.divCoord, self.divSpawnMode, self.divPlayer, self.divRadius }) do
        if dy then
            self:drawRect(lx, dy, lw, 1, 0.35, T.borderDim.r, T.borderDim.g, T.borderDim.b)
        end
    end
end

function AdminItemSpawnerPanel:updateCoordLabel()
    if self.lblCoordValue then
        self.lblCoordValue:setName(
            string.format("X: %d, Y: %d, Z: %d", self.selectX, self.selectY, self.selectZ))
    end
end

function AdminItemSpawnerPanel:populatePlayerList()
    if not self.playerList then return end
    self.playerList:clear()
    if Globals.isSingleplayer then
        local name = self.playerObj:getDisplayName()
        local item = { username = self.playerObj:getUsername(), displayName = name }
        self.playerList:addItem(name, item)
    elseif Globals.isClient then
        if not self.scoreboard then return end
        for i = 0, self.scoreboard.usernames:size() - 1 do
            local username    = self.scoreboard.usernames:get(i)
            local displayName = self.scoreboard.displayNames:get(i)
            if username ~= self.playerObj:getUsername() then
                local item = { username = username, displayName = displayName }
                local row  = self.playerList:addItem(displayName, item)
                if row and username ~= displayName then
                    row.tooltip = username
                end
            end
        end
    end
end

function AdminItemSpawnerPanel.drawPlayerListItem(list, y, item, alt)
    local isSelected = (list.selected == item.index)
    local bg = isSelected and C.COLORS.LIST_HIGHLIGHT
        or (alt and C.COLORS.PANEL or C.COLORS.BACKGROUND)
    list:drawRect(0, y, list:getWidth(), list.itemheight - 1, bg.a, bg.r, bg.g, bg.b)
    local tc = C.COLORS.TEXT
    list:drawText(item.text, 6, y + 3, tc.r, tc.g, tc.b, tc.a, UIFont.Small)
    return y + list.itemheight
end

function AdminItemSpawnerPanel:onSpawnModeChanged(buttons, index)
    local mode = (index == 1 and C.SPAWN_MODES.LOCAL)
        or (index == 2 and C.SPAWN_MODES.GLOBAL)
        or (index == 3 and C.SPAWN_MODES.PLAYER)
    self.spawnMode = mode
    local isPlayerMode = (mode == C.SPAWN_MODES.PLAYER)
    local col = isPlayerMode and C.COLORS.PLAYER_SECTION or C.COLORS.PLAYER_SECTION_INACTIVE
    self.lblPlayerTitle1:setColor(col.r, col.g, col.b)
    self.lblPlayerTitle2:setColor(col.r, col.g, col.b)
    self.playerList.borderColor = Theme.copy(col)
    self.entryRadius:setEditable(mode == C.SPAWN_MODES.LOCAL)
    if isPlayerMode then
        self:populatePlayerList()
    end
end

function AdminItemSpawnerPanel:onButtonClick(button)
    if button.internal == "PICK_SQUARE" then
        self.cursor = ISSelectCursor:new(self.playerObj, self, self.onSquareSelected)
        getCell():setDrag(self.cursor, self.playerObj:getPlayerNum())
    elseif button.internal == "SPAWN" then
        self:doSpawn()
    elseif button.internal == "CANCEL" then
        self:close()
    end
end

function AdminItemSpawnerPanel:onSquareSelected(square)
    self:removeMarker()
    self.selectX = square:getX()
    self.selectY = square:getY()
    self.selectZ = square:getZ()
    self:updateCoordLabel()
    self:addMarker(square, self:getRadius() + 1)
end

function AdminItemSpawnerPanel:parseItemsList(text)
    local items = {}
    for line in text:gmatch("[^\r\n]+") do
        for entry in line:gmatch("[^;]+") do
            entry = entry:trim()
            if entry ~= "" then
                local itemType, count = entry:match("([^=]+)=(%d+)")
                if itemType then
                    itemType = itemType:trim()
                    count = tonumber(count)
                    items[itemType] = (items[itemType] or 0) + count
                else
                    itemType = entry
                    items[itemType] = (items[itemType] or 0) + 1
                end
            end
        end
    end
    return items
end

function AdminItemSpawnerPanel:doSpawn()
    local items = self:parseItemsList(self.entryItems:getText())
    local args = {
        steamID      = getCurrentUserSteamID(),
        items        = items,
        x            = self.selectX,
        y            = self.selectY,
        z            = self.selectZ,
        radius       = tonumber(self.entryRadius:getText()) or 1,
        spawnMode    = self.spawnMode,
        targetPlayer = self.playerList.selected > 0
            and self.playerList.items[self.playerList.selected].item
            and self.playerList.items[self.playerList.selected].item.username or nil,
    }
    if Globals.isClient then
        sendClientCommand(self.playerObj, "AdminItemSpawner", "SpawnItems", args)
    else
        AdminItemSpawner.Client.SpawnItems(self.playerObj, args)
    end
end

function AdminItemSpawnerPanel:getRadius()
    local radius = self.entryRadius:getInternalText()
    return (tonumber(radius) or 1) - 1
end

function AdminItemSpawnerPanel:addMarker(square, radius)
    self.marker = getWorldMarkers():addGridSquareMarker(square, 1.0, 0.0, 0.0, true, radius)
    self.marker:setScaleCircleTexture(true)
end

function AdminItemSpawnerPanel:removeMarker()
    if self.marker then
        self.marker:remove()
        self.marker = nil
    end
    if self.arrow then
        self.arrow:remove()
        self.arrow = nil
    end
end

function AdminItemSpawnerPanel:close()
    self:removeMarker()
    self:setVisible(false)
    self:removeFromUIManager()
    AdminItemSpawnerPanel.instance = nil
end

function AdminItemSpawnerPanel.onScoreboardUpdate(usernames, displayNames, steamIDs)
    if AdminItemSpawnerPanel.instance then
        AdminItemSpawnerPanel.instance.scoreboard = {
            usernames    = usernames,
            displayNames = displayNames,
            steamIDs     = steamIDs,
        }
        AdminItemSpawnerPanel.instance:populatePlayerList()
    end
end

AdminItemSpawnerPanel.OnMiniScoreboardUpdate = function()
    if ISMiniScoreboardUI.instance then
        scoreboardUpdate()
    end
end

Events.OnScoreboardUpdate.Add(AdminItemSpawnerPanel.onScoreboardUpdate)
Events.OnMiniScoreboardUpdate.Add(AdminItemSpawnerPanel.OnMiniScoreboardUpdate)

function AdminItemSpawnerPanel.openPanel()
    if AdminItemSpawnerPanel.instance then
        AdminItemSpawnerPanel.instance:close()
        return
    end
    local sw    = getCore():getScreenWidth()
    local sh    = getCore():getScreenHeight()
    local w     = math.min(C.DEFAULT_W, math.max(C.MIN_W, sw - 40))
    local h     = math.min(C.DEFAULT_H, math.max(C.MIN_H, sh - 40))
    local x     = math.max(20, math.floor((sw - w) / 2))
    local y     = math.max(20, math.floor((sh - h) / 2))

    local panel = AdminItemSpawnerPanel:new(x, y, getPlayer(), getPlayer():getSquare())
    panel:initialise()
    panel:addToUIManager()
    AdminItemSpawnerPanel.instance = panel
end

local MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")

MenuDock.registerButton({
    id                 = "admin_item_spawner",
    title              = getText("IGUI_AIS_AdminItemSpawner"),
    icon               = "media/ui/ui_icon_admin_item_spawner.png",
    minimumAccessLevel = "Admin",
    allowSinglePlayer  = true,
    onClick            = function(playerNum, entry)
        AdminItemSpawnerPanel.openPanel()
    end,
})
