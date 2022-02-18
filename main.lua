Addon = LibStub("AceAddon-3.0"):NewAddon("ElmuTrinkets", "AceConsole-3.0", "Inspect-3.1.0", "AceHook-3.0", "AceEvent-3.0")
local backgroundFrame

-- array of buttons
local ButtonFrames = {}

local pad = 2 --padding between buttons
local size = 25 --button size
local row = 3 --# of trinkets per row

-- How many trinket button frames to create
local TRINKET_BUTTON_FRAME_COUNT = 30

-- map of item id to texture
local iconTextureCache = {}

-- enable debug prints
local DEBUG = false

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

local function GetOrCreateTexture(b, itemId)
    -- icon texture
    local _, textureId = ItemRack.GetInfoByID(itemId)

    if iconTextureCache[itemId] then
        local data = iconTextureCache[itemId]
        return data.texture, data.textureId
    end

    local frameName = b:GetName()
    local t = b:CreateTexture(frameName.."Icon","BACKGROUND",nil,-6)
    t:SetWidth(size)
    t:SetHeight(size)

    iconTextureCache[itemId] = {
        texture = t,
        textureId = textureId,
    }

    return t, textureId
end

-- Equip an item using ItemRack
local function EquipItem(index, itemId, mouseButton)
    -- can be "RightButton"
    mouseButton = mouseButton or "LeftButton"
    local btn = ItemRack.CreateMenuButton(1, itemId)
    ItemRack.Menu[btn:GetID()] = itemId
    ItemRack.MenuOnClick(btn, mouseButton)

    local btnFrame = ButtonFrames[index]
    CooldownFrame_Set(btnFrame.CooldownFrame, 0, 0)
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
    DebugPrint("Setting trinket for button frame %s", index)
    local btnFrame = ButtonFrames[index]
    local _, _, _, _, _, _, itemLink, _, _, itemId = GetContainerItemInfo(bag, slot)

    local texture, textureId = GetOrCreateTexture(btnFrame, itemId)
    texture:SetTexture(textureId)
    texture:SetAllPoints(btnFrame) -- make texture same size as button

    btnFrame:SetSize(size, size)
    btnFrame:SetFrameStrata("HIGH")
    btnFrame:RegisterForClicks("AnyUp")

    btnFrame:SetNormalTexture(textureId)
    btnFrame:SetPushedTexture(textureId)
    btnFrame:SetHighlightTexture(textureId)

    -- set variables on button frame
    btnFrame.itemId = itemId

    btnFrame:SetScript("OnClick", function(self, button, down)
        local btn = ItemRack.CreateMenuButton(1, itemId)
        EquipItem(index, itemId, button)
    end)

    btnFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(backgroundFrame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetBagItem(bag, slot)
        GameTooltip:Show()
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
            -- btnFrame:Hide()
        else
            local trinketData = trinkets[i]
            SetTrinketForButtonFrame(i, trinketData.Bag, trinketData.Slot)
        end
    end

    UpdateTrinketCooldowns()
end

-- This creates the initial slots for trinkets, should only be called once
local function CreateTrinketButtons()
    local x = -pad
    local y = -pad

    for i = 1, TRINKET_BUTTON_FRAME_COUNT do
        local btnFrame = CreateFrame("CheckButton", "ElmuTrinketButton"..i, backgroundFrame, "SecureActionButtonTemplate")
        local frameName = btnFrame:GetName()
        DebugPrint("Creating new trinket frame, name: %s ", frameName)

        btnFrame:SetSize(size, size)
        btnFrame:SetFrameStrata("HIGH")

        -- Create cooldown frame
        local cd = CreateFrame("Cooldown", frameName.."Cooldown", btnFrame, "CooldownFrameTemplate")
        cd:SetAllPoints()
        btnFrame.CooldownFrame = cd

        table.insert(ButtonFrames, btnFrame)

        btnFrame:SetPoint("CENTER", x, y)
        x = x + size + pad
        if x >= size * row then
            x = -pad
            y = y + size + pad
            DebugPrint("%d, %d", x, y)
        end
    end
end

function Addon:OnInitialize()
    Addon:Print("Initialized addon")
end

function Addon:OnEnable()
    Addon:Print("Enabled addon")

    -- Needed for ItemRack to work
    ItemRack.menuOpen = 13

    backgroundFrame = CreateFrame("Button", "ElmuRackFrame", UIParent)
    backgroundFrame:EnableMouse(false)
    backgroundFrame:SetPoint("CENTER", 500, 0)
    backgroundFrame:SetSize(200, 300)

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
