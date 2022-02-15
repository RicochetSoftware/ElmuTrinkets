Addon = LibStub("AceAddon-3.0"):NewAddon("ElmuTrinkets", "AceConsole-3.0", "Inspect-3.1.0", "AceHook-3.0", "AceEvent-3.0")
local frame
local Buttons = {}
local ButtonFrames = {}
local pad = 2
local size = 25
local row = 3

local function EquipItem(itemId, mouseButton)
    -- can be "RightButton"
    mouseButton = mouseButton or "LeftButton"
    local btn = ItemRack.CreateMenuButton(1, itemId)
    ItemRack.Menu[btn:GetID()] = itemId
    ItemRack.MenuOnClick(btn, mouseButton)
end

local function CreateTrinketButton(n, itemId, data, xo, yo)
    local b = CreateFrame("CheckButton", "ElmuTrinketButton"..n, frame, "SecureActionButtonTemplate");
    --icon texture
    local _, texture = ItemRack.GetInfoByID(itemId)
    local t = b:CreateTexture("ElmuTrinketButton"..n.."Icon","BACKGROUND",nil,-6)
    b:SetPoint("CENTER", xo or 0, yo or 0)
    b:SetSize(size, size)
    t:SetTexture(texture)
    t:SetWidth(size)
    t:SetHeight(size)
    --t:SetTexCoord(0.1,0.9,0.1,0.9) --cut out crappy icon border
    t:SetAllPoints(b) --make texture same size as button
    b:SetFrameStrata("HIGH")
    b:RegisterForClicks("AnyUp")
    b:SetNormalTexture(texture)
    b:SetPushedTexture(texture)
    b:SetHighlightTexture(texture)

    local cd = CreateFrame("Cooldown", "ElmuTrinketButton"..n.."Cooldown", b, "CooldownFrameTemplate")
    cd:SetAllPoints()

    b:SetScript("OnClick", function(self, button, down)
        local btn = ItemRack.CreateMenuButton(1, itemId)
        EquipItem(itemId, button)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(frame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetBagItem(data.Bag, data.Slot)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

	return b
end

function CreateTrinketButtons()
    local id = 13 --idk doesnt work without an id, fuck itemrack
    for i = 0, 4 do
        for j = 1,GetContainerNumSlots(i) do
            local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(i, j)
            itemName,itemTexture,equipSlot = ItemRack.GetInfoByID(itemID)
            --Addon:Print(tostring(itemName).." > "..tostring(equipSlot))
            if equipSlot == "INVTYPE_TRINKET" and ItemRack.SlotInfo[id][equipSlot] and ItemRack.PlayerCanWear(id,i,j) and (ItemRackSettings.HideTradables=="OFF" or ItemRack.IsSoulbound(i,j)) then
                if id ~= 0 or not ItemRack.AlreadyInMenu(itemID) then
                    table.insert(Buttons, {ID = itemID; Link = itemLink; Bag = i; Slot = j; SlotInfo = ItemRack.SlotInfo[id][equipSlot]})
                end
            end
        end
    end

    local x = -pad
    local y = -pad
    for n, data in ipairs(Buttons) do
        local id = data.ID
        local b = CreateTrinketButton(n, id, data, x, y)
        table.insert(ButtonFrames, b)
        x = x + size + pad
        if x >= size * row then
            x = -pad
            y = y + size + pad
        end
    end
end


function Addon:OnInitialize()
    Addon:Print("Initialized addon")
end

function Addon:OnEnable()
    Addon:Print("Enabled addon")
    ItemRack.menuOpen = 13
    Addon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", function()
        for n, data in ipairs(Buttons) do
            local start, duration, enable = GetItemCooldown(data.ID)
            --Addon:Print(string.format("ElmuTrinketButton%sCooldown %s %s %s", n, start, duration, enable))
            CooldownFrame_Set(_G["ElmuTrinketButton" .. n .. "Cooldown"], start, duration, enable)
        end
    end)

    Addon:RegisterEvent("BAG_UPDATE", function()
        for i = 1, #ButtonFrames do
            ButtonFrames[i]:Hide()
            ButtonFrames[i] = nil
        end
        ButtonFrames = {}
        CreateTrinketButtons()
    end)


    frame = CreateFrame("Button", "ElmuRackFrame", UIParent)
    frame:EnableMouse(false)
    frame:SetPoint("CENTER", 500, 0)
    frame:SetSize(200, 300)

    CreateTrinketButtons()
end

function Addon:OnDisable()
    Addon:Print("Disabled addon")
end
