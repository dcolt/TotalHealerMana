thm = {}
thm.hasWarned = false;
thm.hasCritical = false;

local f = CreateFrame("StatusBar", "THM_Frame",UIParent)

f:RegisterEvent("UNIT_POWER_UPDATE")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("GROUP_JOINED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

function f:ADDON_LOADED(addonName)
	if addonName == "DC-TotalHealerMana" then
		f:UnregisterEvent('ADDON_LOADED')
		thm.onLoad()
		f:RegisterEvent("CHAT_MSG_ADDON")
		C_ChatInfo.RegisterAddonMessagePrefix("DCTHM")
	end
end

function f:UNIT_POWER_UPDATE()
	f.title:SetText(thm.updateData())
end

function f:GROUP_JOINED()
	local amountInGroup = GetNumGroupMembers()
	if amountInGroup == 1 then
		DCTHM.doWarn = true
	else
		DCTHM.doWarn = false
	end
end

thm.timer = C_Timer.NewTimer(0.5, function()
end);
thm.timer:Cancel()

function thm:GetRaidIndex()
	local index = 0;
	for raidIndex = 1,GetNumGroupMembers() do
		local me = GetUnitName("player")
		if GetUnitName("raid"..raidIndex) == me then
			index = raidIndex
		end
	end
	return index
end

local raids = {"Blackwing Lair", "Molten Core", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Zul'Gurub", "Naxxramas", "Onyxia's Lair"}

function f:GROUP_ROSTER_UPDATE(...)
	if IsInRaid() then
		if tContains(raids, GetZoneText()) then
			local raidIndex = thm:GetRaidIndex()
			if raidIndex > 0 then
				local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(raidIndex)
				if rank > 0 then
					C_ChatInfo.SendAddonMessage("DCTHM", raidIndex, "RAID")
					DCTHM.doWarn = true
				end
			end
		else
			DCTHM.doWarn = false
		end
	end
end

function f:CHAT_MSG_ADDON(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
	if channel == "RAID" and prefix == "DCTHM" and target ~= GetUnitName("player", true) then
		DCTHM.doWarn = thm:GetRaidIndex() < tonumber(text) or false
		--print("CHAT_MSG_ADDON")
		--print(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
	end
end

f:SetScript("OnEvent", function (self, event, ...)
	return self[event](self,...)
end)

function thm.setDefaultValues()
	DCTHM = _G["DCTHM"] or {["full"] = false}
	if DCTHM[doWarn] == nil then
		DCTHM.doWarn = false;
		DCTHM.warnAt = 25;
		DCTHM.critical = 10;
	end
	if  DCTHM[blacklist] == nil then
		DCTHM.blacklist = {};
	end
end

thm.setDefaultValues()

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("RightButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
	
function thm:getIndex(t, v)
	local i = 1;
	
	while t[i] do
		if (v == t[i]) then
			return i;
		end
		i = i + 1
	end
	
	return 0;
end

function thm:blacklistPlayer(player)
	-- If no name entered for blacklist command, print current blacklist
	if player == nil then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r ~ Current Blacklist ~")
		local blStr = table.concat(DCTHM.blacklist, "\n|cff00D1FFTHM:|r ")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r " .. blStr)
		
	-- Otherwise, add or remove the named player from the blacklist
	else
		local index = thm:getIndex(DCTHM.blacklist, player)
		if (index > 0) then
			table.remove(DCTHM.blacklist, index)
			DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r " .. player .. " no longer blacklisted")
		else
			table.insert(DCTHM.blacklist, player)
			DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r " .. player .. " blacklisted")
		end
	end
end

function thm:updateData(msg)
	if IsInRaid() then
		local players = GetNumGroupMembers()

		local total, totalMax = 0, 0
		for groupindex = 1,players do
			if not tContains(DCTHM.blacklist, GetUnitName("raid"..groupindex)) then
				local id = select(3, UnitClass("raid"..groupindex))
				if (id == 2 or id == 5 or id == 11 or id == 7) then
					total = total + UnitPower("raid"..groupindex,0)
					totalMax = totalMax + UnitPowerMax("raid"..groupindex,0)
				end
			end
		end
	
		local persentage = (100*(total/totalMax))
		local output = string.format("%.0f%%", persentage)
		if DCTHM.full then
			output = output .. string.format(" - %d/%d", total, totalMax)
		end

		if not (totalMax > 0) then
			return
		end
		
		thm:resetWarnings(persentage)

		if DCTHM.doWarn then
			if not thm.hasWarned and persentage < DCTHM.warnAt then
				thm.hasWarned = true
				SendChatMessage("Warning: Low healer mana! "..string.format("%.0f%%", persentage), "RAID_WARNING")
			end
			if not thm.hasCritical and persentage < DCTHM.critical then
				thm.hasCritical = true
				SendChatMessage("Critical: Low healer mana! "..string.format("%.0f%%", persentage), "RAID_WARNING")
			end
		end
		
		if not f:IsShown() and totalMax > 0 then
			f:Show()
		end
		
		f:SetMinMaxValues(0, totalMax)
		f:SetValue(total)
		
		return output
	elseif IsInGroup() then
		local players = GetNumGroupMembers()

		local total, totalMax = 0, 0
		for groupindex = 1,players do
			if not tContains(DCTHM.blacklist, GetUnitName("party"..groupindex)) then
				local id = select(3, UnitClass("party"..groupindex))
				if (id == 2 or id == 5 or id == 11 or id == 7) then
					total = total + UnitPower("party"..groupindex,0)
					totalMax = totalMax + UnitPowerMax("party"..groupindex,0)
				end
			end
		end
		
		if not tContains(DCTHM.blacklist, GetUnitName("player")) then
			local id = select(3, UnitClass("player"))
			if (id == 2 or id == 5 or id == 11 or id == 7) then
				total = total + UnitPower("player",0);
				totalMax = totalMax + UnitPowerMax("player",0);
			end
		end

		local persentage = (100*(total/totalMax))
		local output = string.format("%.0f%%", persentage)
		if DCTHM.full then
			output = output .. string.format(" - %d/%d", total, totalMax)
		end

		if not (totalMax > 0) then
			return
		end
		
		thm:resetWarnings(persentage)

		if DCTHM.doWarn then
			if not thm.hasWarned and persentage < DCTHM.warnAt then
				thm.hasWarned = true
				SendChatMessage("Warning: Low healer mana! "..string.format("%.0f%%", persentage), "PARTY")
				--print("Warning: Low healer mana! "..string.format("%.0f%%", persentage))
			end
			if not thm.hasCritical and persentage < DCTHM.critical then
				thm.hasCritical = true
				SendChatMessage("Critical: Low healer mana! "..string.format("%.0f%%", persentage), "PARTY")
				--print("Critical: Low healer mana! "..string.format("%.0f%%", persentage))
			end
		end
		
		if not f:IsShown() and totalMax > 0 then
			f:Show()
		end
		
		f:SetMinMaxValues(0, totalMax)
		f:SetValue(total)
		
		return output
	end
	
	if f:IsShown() then
		f:Hide()
	end
	return ""
end

function thm:firstUpper(str)
	return string.upper(str:sub(1,1))..string.lower(str:sub(2))
end

function thm:resetWarnings(persentage)
	if not InCombatLockdown() then
		if persentage > DCTHM.warnAt + 10 then
			thm.hasWarned = false
		end
		if persentage > DCTHM.critical + 10 then
			thm.hasCritical = false
		end
	end
end

local function main(msg)
	local msg_split = {}
	for v in string.gmatch(msg, "[^ ]+") do
		table.insert(msg_split, v)
	end
	
	if msg_split[1] == "toggle" then
		DCTHM.full = not DCTHM.full
	elseif msg_split[1] == "bl" then
		if #msg_split >=2 then
			msg_split[2] = thm:firstUpper(msg_split[2]);
		end
		thm:blacklistPlayer(msg_split[2]);
	elseif msg_split[1] == "w" then
		if msg_split[2] == "toggle" then
			DCTHM.doWarn = not DCTHM.doWarn
			if DCTHM.doWarn then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r Will now show a warning")
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r Will not show a warning")
			end
		else
			local amount = tonumber(msg_split[2])
			if amount > 0 and amount < 100 then
				DCTHM.warnAt = amount
				DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r Warning limit set to " .. amount)
			end
		end
	elseif msg_split[1] == "wc" then
		local amount = tonumber(msg_split[2])
		if amount > 0 and amount < 100 then
			DCTHM.critical = amount
				DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r Critical limit set to " .. amount)
		end
	else 
		local output = thm:updateData()
		if (#output ~= 0) then
			output = "Healers total mana: "..output
			if msg_split[1] == "p" then
				SendChatMessage(output, "PARTY")
			elseif msg_split[1] == "r" then
				SendChatMessage(output, "RAID")	
			elseif msg_split[1] == "rw" then
				SendChatMessage(output, "RAID_WARNING")
			else
				f.title:SetText(output)
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00D1FFTHM:|r You need to be in a raid group")
		end
	end
end

function thm:onLoad()
	SLASH_THM1 = '/thm'
	SlashCmdList["THM"] = main
	
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("RightButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)

	f:SetPoint("CENTER",0,0)
	f:SetSize(200,20)
	--statusbar background
	f.bg = f:CreateTexture(nil,"BACKGROUND",nil,-8)
	f.bg:SetAllPoints(f)
	f.bg:SetColorTexture(0/255,191/255,255/255)
	f.bg:SetAlpha(0.2)
	--statusbar texture
	local tex = f:CreateTexture(nil,"BACKGROUND",nil,-6)
	tex:SetColorTexture(0/255,191/255,255/255)
	f:SetStatusBarTexture(tex)
	f:SetStatusBarColor(0/255,191/255,255/255)
	f:SetAlpha(0.8)
	--values
	f:SetMinMaxValues(0, 0)
	f:SetValue(0)
	
	f:SetFrameStrata("BACKGROUND")
	
	f.title = f:CreateFontString(nil, "OVERLAY")
	f.title:SetFontObject("GameFontHighlight", 24)
	f.title:SetPoint("CENTER", f, "CENTER", 0, 0)

	f:SetPoint("CENTER",0,0)
	f:Hide()
end
