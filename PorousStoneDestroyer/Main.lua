--[[

	The MIT License (MIT)

	Copyright (c) 2021 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Path to this addon's asset folder
local Path = [[Interface\AddOns\]]..(...)..[[\Assets\]]

local Frame = CreateFrame("Frame")
local Button = CreateFrame("Button", "PorousStoneDestroyerButton", UIParent)

-- Lua API
local _G = _G
local table_wipe = table.wipe

-- WoW API
local DeleteCursorItem = DeleteCursorItem
local GetContainerItemID = GetContainerItemID
local GetContainerNumSlots = GetContainerNumSlots
local PickupContainerItem = PickupContainerItem

-- WoW Objects
local StaticPopupDialogs = StaticPopupDialogs

-- Blacklisted items
-- Currently only set up for Porous Stone, 
-- but you can in theory add any itemID to it.
-- Also, no, I will not write any system for 
-- users to add custom items in-game to this list.
local BlacklistedItem = {
	[171840] = true -- Porous Stone
}

-- The static popups we modify to remove editboxes from
local Dialogs = {
	[DELETE_GOOD_QUEST_ITEM] = true,
	[DELETE_GOOD_ITEM] = true,
	[DELETE_ITEM] = true,
	[DELETE_QUEST_ITEM] = true
}

Button.OnClick = function(self)
	if (not self:IsShown()) then
		return
	end
	for bag = 0,4,1 do
		for slot = 1,GetContainerNumSlots(bag),1 do 
			local itemID = GetContainerItemID(bag, slot)
			if (itemID) and (BlacklistedItem[itemID]) then 
				ClearCursor()
				PickupContainerItem(bag,slot)
				DeleteCursorItem() -- Protected, needs a hardware event.
			end 
		end 
	end
end

Button.OnEnable = function(self)
	self:SetScript("OnClick", Button.OnClick)
end

Button.OnInitialize = function(self)
	self:Hide()
	self:SetIgnoreParentScale(true)
	self:SetScale(768/1080)
	self:SetSize(80,80)
	self:SetPoint("CENTER", 100, 20)

	self.Border = self.Border or self:CreateTexture()
	self.Border:SetDrawLayer("BORDER")
	self.Border:SetAllPoints()
	self.Border:SetVertexColor(.8, .76, .72)
	self.Border:SetTexture(Path.."button-big-circular.tga")

	self.Icon = self.Icon or self:CreateTexture()
	self.Icon:SetDrawLayer("ARTWORK")
	self.Icon:SetPoint("TOPLEFT", 11, -11)
	self.Icon:SetPoint("BOTTOMRIGHT", -11, 11)
	self.Icon:SetMask(Path.."actionbutton-mask-circular.tga")
	self.Icon:SetTexture(3764219) -- https://www.wowhead.com/item=171840/porous-stone

end

Frame.DeleteContainerConfirm = function(self)
	local popup, info
	for index = 1, STATICPOPUP_NUMDIALOGS, 1 do
		local frame = _G["StaticPopup"..index]
		if (frame and frame.which and Dialogs[frame.which] and frame:IsShown()) then
			popup = frame
			info = StaticPopupDialogs[frame.which]
			break
		end
	end
	if (not popup) then 
		return 
	end

	local editBox = _G[popup:GetName() .. "EditBox"]
	if (editBox and editBox:IsShown()) then 
		editBox:Hide()

		local button = _G[popup:GetName() .. "Button1"]
		button:Enable()

		if (not popup.link) then 
			popup.link = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			popup.link:SetPoint("CENTER", editBox)
			popup.link:Hide()
			popup:HookScript("OnHide", function() popup.link:Hide() end)
		end 

		popup.link:SetText((select(3, GetCursorInfo())))
		popup.link:Show()

	elseif (popup.link) then 
		popup.link:Hide()
	end
end

Frame.ParseContainerGarbage = function(self)
	local show
	for bag = 0,4,1 do
		for slot = 1,GetContainerNumSlots(bag),1 do 
			local itemID = GetContainerItemID(bag, slot)
			if (itemID) and (BlacklistedItem[itemID]) then 
				show = true
				break
			end 
		end 
	end
	if (show) and (not Button:IsShown()) then
		Button:Show()
	elseif (not show) and (Button:IsShown()) then
		Button:Hide()
	end
end

Frame.OnEvent = function(self, event, ...) 
	if (event == "UNIT_INVENTORY_CHANGED") then 
		local unitID = ...
		if (unitID ~= "player") then 
			return 
		end
	end
	if (event == "DELETE_ITEM_CONFIRM") then
		self:DeleteContainerConfirm()
		return
	end
	self:ParseContainerGarbage()
end

Frame.OnUpdate = function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed > 10) then 
		self.elapsed = nil
		self:Hide()
		self:SetScript("OnUpdate", nil)
		self:OnEnable()
	end 
end

Frame.OnEnable = function(self)
	Button:OnEnable()
	self:SetScript("OnEvent", Frame.OnEvent)
	self:RegisterEvent("BAG_UPDATE") 
	self:RegisterEvent("BAG_UPDATE_DELAYED") 
	self:RegisterEvent("UNIT_INVENTORY_CHANGED") 
	self:RegisterEvent("DELETE_ITEM_CONFIRM")
	self:ParseContainerGarbage()
end

Frame.OnInitialize = function(self)
	Button:OnInitialize()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:SetScript("OnEvent", nil)
	self:SetScript("OnUpdate", self.OnUpdate)
end

Frame:SetScript("OnEvent", Frame.OnInitialize)
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
