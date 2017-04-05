-- ===================== --
--	SLOT CONFIGURATIONS  --
-- ===================== --

-- Action bar offsets.
RIGHT_ACTION_BAR_1 = 24
RIGHT_ACTION_BAR_2 = 36
BOTTOM_RIGHT_ACTION_BAR = 48
BOTTOM_LEFT_ACTION_BAR = 60

-- Action bar selection.
COMMAND_BAR_1 = RIGHT_ACTION_BAR_1
COMMAND_BAR_2 = RIGHT_ACTION_BAR_2

-- Pass values 1 - 12 for argument n to get appropriate SlotID from top to bottom.
-- Let the bar argument represent the command bar constants (1 or 2). 
function Slot(n, bar)
	return n + (bar == 2 and COMMAND_BAR_2 or COMMAND_BAR_1)
end

-- Slot selection.
MOUNT = Slot(7, 1)
MOUNT_GEAR = Slot(1, 1)
COMBAT_GEAR = Slot(4, 1)
ATTACK = Slot(2, 1)
THROW = Slot(2, 2)
RIPOSTE = Slot(3, 2)


-- ================ --
--	SLASH COMMANDS  --
-- ================ --

-- Test.
SLASH_TEST1 = "/test"
SlashCmdList.TEST = function (arg)
	Print("Running test...")
end

view = 0
-- Toggle camera view.
SLASH_VIEW1 = "/view"
SlashCmdList.VIEW = function()
	view = view == 1 and 2 or 1
	SetView(view)
end

-- CommandBar toggle.
SLASH_TOGGLE1 = "/toggle"
SlashCmdList.TOGGLE = function (reload)
	-- Toggle action bars.
	showBar1, showBar2, showBar3, showBar4 = GetActionBarToggles()
	SetActionBarToggles(showBar1, showBar2, not showBar3, not showBar4)
	if reload then
		Hang(1)
		ReloadUI()
	end
end

TRINKET = 13
-- Safe trinket pop and out of combat mount.
SLASH_TRINKET1 = "/trinket"
SlashCmdList.TRINKET = function()
	Dismount()
	if PlayerInCombat() and TargetIsHostile() then
		-- Use trinket if in combat and engaged with a hostile target.
		UseInventoryItem(TRINKET)
	else
		-- Else mount.
		UseAction(MOUNT)
	end
end

CARROT_ALIAS = "Food"
-- Toggle a specified set of equipment for mounting or combat.
SLASH_MOUNT1 = "/mount"
SlashCmdList.MOUNT = function()
	slot = MOUNT_GEAR
	trinketIcon = GetInventoryItemTexture("player", TRINKET)
	if string.find(trinketIcon, CARROT_ALIAS) then
		slot = COMBAT_GEAR
	end
	-- Toggle each equipment slot.
	for i = 0, 2, 1 do
		-- 0 = gloves.
		-- 1 = boots.
		-- 2 = trinket.
		UseAction(slot + i)
	end
end

-- Main attack script.
SLASH_ATTACK1 = "/attack"
SlashCmdList.ATTACK = function()
	-- Attack if there's a target.
	if TargetIsHostile() then
		Dismount()
		CombatAttack()
	else
		NotWhileDeadError()
	end
end


-- ============== --
--	ROGUE ATTACK  --
-- ============== --

-- Attack procedure: Combat spec.
function CombatAttack()
	if HasBuff("Stealth") then
		CastSpellByName("Sap")
	else
		-- Attempt to use riposte.
		start, duration, enable = GetActionCooldown(RIPOSTE)
		-- If in melee range.
		if IsActionInRange(RIPOSTE) == 1 then
			if IsUsableAction(RIPOSTE) and duration == 0 then
				UseAction(RIPOSTE)
			-- Otherwise, assess combo points.
			elseif GetComboPoints() == 5 then
				CastSpellByName("Eviscerate")
			else 
				CastSpellByName("Sinister Strike")
			end
		end
		-- Start attacking or throwing if in range.
		AttackOrThrow()
	end
end

-- Determine whether to start attacking or throw.
function AttackOrThrow()
	if IsActionInRange(THROW) == 1 then
		UseAction(THROW)
	elseif not IsCurrentAction(ATTACK) then
		UseAction(ATTACK)
	end
end

-- Cast one of two spells depending on whether the player is stealthed.
function IfStealth(toCast, altCast)
	-- Execute the stealth-appropriate action.
	if HasBuff("Stealth") then
		CastSpellByName(toCast)
	elseif altCast then
		CastSpellByName(altCast)
	end
end


-- ============================== --
--	POISON APPLICATION FUNCTIONS  --
-- ============================== --

POISON_BAR = 1
MAIN_HAND, OFF_HAND = 16, 17
-- Automatic poison application algorithm.
function ApplyPoison(slot)
	-- Use poison from the specified slot in the last bag and acquire poison status.
	poisonSlot = Slot(slot, POISON_BAR)
	UseAction(poisonSlot)
	hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges = GetWeaponEnchantInfo()
	
	if hasMainHandEnchant ~= 1 or ShouldRenew(mainHandExpiration, mainHandCharges) then
		-- Attempt to apply poison to main hand.
		ApplyTo(MAIN_HAND, poisonSlot)
		
	elseif hasOffhandEnchant ~= 1 or ShouldRenew(offHandExpiration, offHandCharges) then
		-- Attempt to apply poison to off hand.
		ApplyTo(OFF_HAND, poisonSlot)
		
	else
		-- Cycle off hand application if both weapons have appropriate enchants.
		ApplyTo(OFF_HAND, poisonSlot)
	end
end

-- Execute poison application on the specified weapon slot.
function ApplyTo(weaponSlot, poisonSlot)
	count = GetActionCount(poisonSlot)
	if count > 0 then
		-- Apply poison.
		PickupInventoryItem(weaponSlot)
		ReplaceEnchant()

		-- Print poison application info.
		weapon = weaponSlot == mainHandSlot and "MAIN" or "OFF"
		Print("Preparing " .. weapon .. " hand - " .. (count - 1) .. " poisons left.")
	else
		Print("No more poisons left of the specified type.")
	end
end

MINIMUM_DURATION, MINIMUM_CHARGES = 300, 10
-- Determine whether a poison effect should be applied under given conditions.
function ShouldRenew(expiration, charges)
	return ToSeconds(expiration) < MINIMUM_DURATION or charges < MINIMUM_CHARGES
end


-- ====================== --
--	OTHER GAME FUNCTIONS  --
-- ====================== --

-- Returns whether the player is in combat.
function TargetIsHostile()
	return UnitIsPVP("target") or UnitIsEnemy("player", "target")
end

-- Returns whether the player is in combat.
function PlayerInCombat()
	return UnitAffectingCombat("player") == 1
end

-- Determine whether the player has a certain buff. 
function HasBuff(name, doPrint)
	for i = 1, 100, 1 do
		-- Get each buff and assess whether it matches the specified name.
		buff = UnitBuff("player", i)
		if buff then
			-- Print the buff if instructed.
			if doPrint then
				Print(buff)	
			end
			if string.find(buff, name) then
				-- If it matches.
				return true
			end
		else
			-- If no match was found.
			return false
		end
	end
end

-- Dismount if mounted.
function Dismount()
	if HasBuff("Mount") then UseAction(MOUNT) end
end


-- ============================== --
--	UTILITY AND HELPER FUNCTIONS  --
-- ============================== --

-- Print a message to the console, if it exists.
function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
end

-- Calculate milliseconds to seconds.
function ToSeconds(milliseconds)
	return milliseconds / 1000;
end

-- Split a string into an array by a delimiter - javascript style!
function Split(str, delimiter)
	-- If there is no delimiter, or the delimiter is an empty string.
	if not delimiter or string.len(delimiter) <= 0 then error("Function Split: missing delimiter.") end
	-- n is fairly arbitrary.
	n = string.len(str)
	array = { n = 0 }
	for i = 0, n, 1 do
		-- Search for the first occurrence of the delimiter.
		index = string.find(str, delimiter)
		if index and index > 0 then
			-- If the delimiter matches.
			name = string.sub(str, 0, index - 1)
			str = string.sub(str, index + string.len(delimiter))
			array[i] = name
		elseif i > 0 then
			-- If any strings are already in the array, ergo previous matches were found.
			array[i] = str
			break
		else
			-- If there was no delimiter match and no strings were added to the array.
			 error("Function Split: delimiter '" .. delimiter .. "' not found.")
		end
	end
	-- Return the resulting array of strings.
	return array
end

-- HACK:
MAGICAL_TIME_RATIO = 30000
-- Hang the thread for a moment to allow for previous invocations to finish execution.
-- Argument is approximately seconds.
function Hang(schmeconds)
	time = schmeconds * MAGICAL_TIME_RATIO
	for i = 0, time, 1 do
		Print(i)
	end
end