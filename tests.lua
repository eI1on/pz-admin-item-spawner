local defaultMarkers = require("MapMarkerSystem/MARKER_TEMPLATE")

local centerX = 8000
local centerY = 11000
local radius = 5000

local function getRandomCoordinate()
    local angle = math.rad(ZombRand(360))
    local dist = ZombRand(radius)
    local x = math.floor(centerX + math.cos(angle) * dist)
    local y = math.floor(centerY + math.sin(angle) * dist)
    return x, y
end

local function createRandomRectangleCoordinates()
    local x, y = getRandomCoordinate()
    return {
        center = { x = x, y = y },
        width = ZombRand(50, 200),
        height = ZombRand(50, 200)
    }
end

local function createRandomAreaCoordinates()
    local x1, y1 = getRandomCoordinate()
    local x2, y2 = getRandomCoordinate()
    return {
        nw = { x = math.min(x1, x2), y = math.min(y1, y2) },
        se = { x = math.max(x1, x2), y = math.max(y1, y2) }
    }
end

local function getRandomColor()
    return {
        r = ZombRandFloat(0.0, 1.0),
        g = ZombRandFloat(0.0, 1.0),
        b = ZombRandFloat(0.0, 1.0),
        a = 1.0           
    }
end

for markerType, markerData in pairs(defaultMarkers) do
    for i = 1, 5 do
        local x, y = getRandomCoordinate()
        local newMarker = {
            name = markerData.name .. "_" .. string.format("%02d", i),
            markerType = markerData.markerType,
            isEnabled = markerData.isEnabled,
            maxZoomLevel = markerData.maxZoomLevel,
        }

        if markerType == "textureType" then
            newMarker.coordinates = { center = { x = x, y = y } }
            newMarker.texturePath = markerData.texturePath
            newMarker.lockZoom = false
            newMarker.scale = ZombRand(2500, 4500)
        elseif markerType == "rectangleType" then
            newMarker.coordinates = createRandomRectangleCoordinates()
            newMarker.color = getRandomColor()
            newMarker.lockZoom = false
            newMarker.scale = 1
        elseif markerType == "areaType" then
            newMarker.coordinates = createRandomAreaCoordinates()
            newMarker.color = getRandomColor()
        end

        sendClientCommand("MapMarkerSystem", "AddMapMarker", { newMapMarker = newMarker })
    end
end


-- DELETE ALL MARKERS
local MapMarkerSystem = require("MapMarkerSystem/Shared");
for i = 1, #MapMarkerSystem.MapMarkers do
    sendClientCommand("MapMarkerSystem", "RemoveMapMarker", { selectedIdx = i });
end