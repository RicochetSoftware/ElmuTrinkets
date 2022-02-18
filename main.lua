Addon = LibStub("AceAddon-3.0"):NewAddon("ElmuTrinkets", "AceConsole-3.0", "Inspect-3.1.0", "AceHook-3.0", "AceEvent-3.0")
local backgroundFrame

-- array of buttons
local ButtonFrames = {}
local db
-- How many trinket button frames to create
local TRINKET_BUTTON_FRAME_COUNT = 30
local optionsFrame
-- map of item id to texture
local iconTextureCache = {}

-- enable debug prints
local DEBUG = false

local options = {
    type = "group",
    args = {
        section = {
            order = 99,
            type = "header",
            name = "Settings",
        },
        toggle = {
            order = 100,
            name = "Toggle Frame Movable",
            desc = "Unlock/Lock the trinket frame",
            type = "toggle",
            get = function(info)  return db.char.Movable end,
            set = function(info, val)
                db.char.Movable = val
                if val then
                    UnlockFrame()
                else
                    LockFrame()
                end
            end
        },
        tooltip = {
            order = 110,
            name = "Show Tooltip",
            desc = "Show tooltips on hover",
            type = "toggle",
            get = function(info) return db.char.ShowTooltip end,
            set = function(info, val) db.char.ShowTooltip = val end
        },
        padding = {
            order = 150,
            name = "Padding",
            desc = "Padding between trinket buttons",
            type = "input",
            get = function(info)
                return tostring(db.char.Padding)
            end,
            set = function(info, val)
                db.char.Padding = tonumber(val)
                RedrawTrinketButtonPositions()
            end
        },
        size = {
            order = 160,
            name = "Size",
            desc = "Size of trinket buttons",
            type = "input",
            get = function(info)
                return tostring(db.char.Size)
            end,
            set = function(info, val)
                db.char.Size = tonumber(val)
                RedrawTrinketButtonPositions()
            end
        },
        rows = {
            order = 170,
            name = "Rows",
            desc = "How many rows of trinkets to show",
            type = "input",
            get = function(info)
                return tostring(db.char.Rows)
            end,
            set = function(info, val)
                db.char.Rows = tonumber(val)
                RedrawTrinketButtonPositions()
            end
        },

    }
}

local defaults = {
    char = {
        RelativePt = "CENTER",
        PosX = 0,
        PosY = 0,
        ShowTooltip = true,
        Movable = false,
        Padding = 2,
        Size = 25,
        Rows = 3,
    }
}

local function DebugPrint(format, ...)
    if DEBUG then
        local args = {...}
        local nargs = #args
        if nargs == 0 then
            Addon:Print(format)
        else
            Addon:Printf(format, ...)
        end
    end
end

function UnlockFrame()
    backgroundFrame.texture:SetColorTexture(0.2, 0.2, 0.2, 0.3)
    DebugPrint("Unlocked frame")
    backgroundFrame:EnableMouse(true)
    backgroundFrame:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    backgroundFrame:SetMovable(true)
end

function LockFrame()
    backgroundFrame.texture:SetColorTexture(0.2, 0.2, 0.2, 0)
    DebugPrint("Locked frame")
    backgroundFrame:EnableMouse(false)
    backgroundFrame:SetMovable(false)
    _, _, relPt, xOfs, yOfs = backgroundFrame:GetPoint()
    db.char.PosX = xOfs
    db.char.PosY = yOfs
    db.char.RelativePt = relPt
    DebugPrint("saving frame at %d %s", xOfs, yOfs)
end

local function GetOrCreateTexture(b, itemId)
    -- icon texture
    local _, textureId = ItemRack.GetInfoByID(itemId)

    if iconTextureCache[itemId] then
        local data = iconTextureCache[itemId]
        return data.texture, data.textureId
    end

    local frameName = b:GetName()
    local t = b:CreateTexture(frameName.."Icon","BACKGROUND",nil,-6)
    t:SetWidth(db.char.Size)
    t:SetHeight(db.char.Size)

    iconTextureCache[itemId] = {
        texture = t,
        textureId = textureId,
    }

    return t, textureId
end

-- Equip an item using ItemRack
local function EquipItem(index, itemId, mouseButton) --fuck itemrack why does it use item id!! what if i have 2 mortars, 1 empty??????
    -- can be "RightButton" or "LeftButton"
    mouseButton = mouseButton or "LeftButton"

    local btnFrame = ButtonFrames[index]
    local itemRackID = ItemRack.GetID(btnFrame.bagIndex, btnFrame.bagSlot)
    local btn = ItemRack.CreateMenuButton(1, itemRackID)
    ItemRack.Menu[btn:GetID()] = itemRackID
    ItemRack.MenuOnClick(btn, mouseButton)
end

-- returns an array of trinkets and their data
local function GetTrinkets()
    local trinkets = {}
    local id = 13 --idk doesnt work without an id, fuck itemrack
    local index = 1
    for i = 0, 4 do
        for j = 1,GetContainerNumSlots(i) do
            local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(i, j)
            itemName,itemTexture,equipSlot = ItemRack.GetInfoByID(itemID)
            --Addon:Print(tostring(itemName).." > "..tostring(equipSlot))
            if equipSlot == "INVTYPE_TRINKET" and ItemRack.SlotInfo[id][equipSlot] and ItemRack.PlayerCanWear(id,i,j) and (ItemRackSettings.HideTradables=="OFF" or ItemRack.IsSoulbound(i,j)) then
                if id ~= 0 or not ItemRack.AlreadyInMenu(itemID) then
                    table.insert(trinkets, {
                        ID = itemID;
                        Link = itemLink;
                        Bag = i;
                        Slot = j;
                        SlotInfo = ItemRack.SlotInfo[id][equipSlot];
                        Index = index;
                    })
                    index = index + 1
                end
            end
        end
    end
    return trinkets
end

local function UpdateTrinketCooldowns()
    for _, data in ipairs(ButtonFrames) do
        if data.itemId ~= nil then
            local start, duration, enable = GetItemCooldown(data.itemId)
            CooldownFrame_Set(data.CooldownFrame, start, duration, enable)
        end
    end
end

-- Sets the trinket icon, cooldown and data for a button frame index
local function SetTrinketForButtonFrame(index, bag, slot)
    --DebugPrint("Setting trinket for button frame %s", index)
    local btnFrame = ButtonFrames[index]
    local _, _, _, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bag, slot)

    local texture, textureId = GetOrCreateTexture(btnFrame, itemId)
    texture:SetTexture(textureId)
    texture:SetAllPoints(btnFrame) -- make texture same size as button

    btnFrame:SetSize(db.char.Size, db.char.Size)
    btnFrame:SetFrameStrata("HIGH")
    btnFrame:RegisterForClicks("AnyUp")

    btnFrame:SetNormalTexture(textureId)
    btnFrame:SetPushedTexture(textureId)
    btnFrame:SetHighlightTexture(textureId)

    -- set variables on button frame
    btnFrame.itemId = itemId
    btnFrame.trinketIconTexture = texture
    btnFrame.bagIndex = bag
    btnFrame.bagSlot = slot

    btnFrame:SetScript("OnClick", function(self, button, down)
        local btn = ItemRack.CreateMenuButton(1, itemId)
        EquipItem(index, itemId, button)
    end)

    btnFrame:SetScript("OnEnter", function(self)
        if db.char.ShowTooltip then
            GameTooltip:SetOwner(btnFrame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetBagItem(bag, slot)
            GameTooltip:Show()
        end
    end)

    btnFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    btnFrame:Show()
end

-- Called when we need to update the entire menu
local function UpdateAllButtonFrames()
    local trinkets = GetTrinkets()

    for i = 1, TRINKET_BUTTON_FRAME_COUNT do
        local btnFrame = ButtonFrames[i]
        if i > #trinkets then
            btnFrame:Hide()
        else
            local trinketData = trinkets[i]
            SetTrinketForButtonFrame(i, trinketData.Bag, trinketData.Slot)
        end
    end

    UpdateTrinketCooldowns()
end

-- This creates the initial slots for trinkets, should only be called once
local function CreateTrinketButtons()
    local x = -db.char.Padding
    local y = -db.char.Padding

    for i = 1, TRINKET_BUTTON_FRAME_COUNT do
        local btnFrame = CreateFrame("CheckButton", "ElmuTrinketButton"..i, backgroundFrame, "SecureActionButtonTemplate")
        local frameName = btnFrame:GetName()
        --DebugPrint("Creating new trinket frame, name: %s ", frameName)

        btnFrame:SetSize(db.char.Size, db.char.Size)
        btnFrame:SetFrameStrata("HIGH")

        -- Create cooldown frame
        local cd = CreateFrame("Cooldown", frameName.."Cooldown", btnFrame, "CooldownFrameTemplate")
        cd:SetAllPoints()
        btnFrame.CooldownFrame = cd

        table.insert(ButtonFrames, btnFrame)

        btnFrame:SetPoint("CENTER", x - 25, y - 50)
        --DebugPrint("%d, %d", x, y)
        x = x + db.char.Size + db.char.Padding
        if x >= db.char.Size * db.char.Rows then
            x = -db.char.Padding
            y = y + db.char.Size + db.char.Padding
        end
    end
end

-- Call when settings change (padding, rows, size) to reposition the current frames
function RedrawTrinketButtonPositions()
    local x = -db.char.Padding
    local y = -db.char.Padding
    
    for i = 1, TRINKET_BUTTON_FRAME_COUNT do
        local btnFrame = ButtonFrames[i]

        -- Update the size of texture and cooldown frame
        if btnFrame.trinketIconTexture then
            btnFrame.trinketIconTexture:SetAllPoints(btnFrame)
        end

        if btnFrame.CooldownFrame then
            btnFrame.CooldownFrame:SetAllPoints()
        end

        btnFrame:SetPoint("CENTER", x - 25, y - 50)
        --DebugPrint("%d, %d", x, y)
        x = x + db.char.Size + db.char.Padding
        if x >= db.char.Size * db.char.Rows then
            x = -db.char.Padding
            y = y + db.char.Size + db.char.Padding
        end
    end
end

function Addon:OnInitialize()
    Addon:Print("Initialized addon")
    db = LibStub("AceDB-3.0"):New("ElmuTrinketsDB", defaults)
    optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ElmuTrinkets", "ElmuTrinkets")
end

function Addon:OnEnable()
    Addon:Print("Enabled addon")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("ElmuTrinkets", options, nil)

    -- Needed for ItemRack to work
    ItemRack.menuOpen = 13

    backgroundFrame = CreateFrame("Button", "ElmuRackFrame", UIParent)
    backgroundFrame:SetFrameStrata("BACKGROUND")
    backgroundFrame:EnableMouse(false)
    DebugPrint("loading frame at %d %s", db.char.PosX, db.char.PosY)
    backgroundFrame:SetPoint(db.char.RelativePt, db.char.PosX, db.char.PosY)
    backgroundFrame:SetSize(100, 200)

    backgroundFrame.texture = backgroundFrame:CreateTexture(nil,"BACKGROUND")
    backgroundFrame.texture:SetAllPoints(backgroundFrame)
    backgroundFrame.texture:SetColorTexture(0.2, 0.2, 0.2, 0)

    --backgroundFrame:Hide()

    backgroundFrame:SetScript("OnMouseDown", function(self)
        if db.char.Movable then
            backgroundFrame:StartMoving()
        end
    end)
    backgroundFrame:SetScript("OnMouseUp", function(self)
        if db.char.Movable then
            backgroundFrame:StopMovingOrSizing()
        end
    end)

    -- Create the frames
    CreateTrinketButtons()

    UpdateAllButtonFrames()

    Addon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function()
        UpdateTrinketCooldowns()
    end)

    Addon:RegisterEvent("BAG_UPDATE", function()
        UpdateAllButtonFrames()
    end)
end

function Addon:OnDisable()
    Addon:Print("Disabled addon")
end
