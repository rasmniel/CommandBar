-- Test.
SLASH_TEST1 = "/test"
SlashCmdList.TEST = function (arg, gui)
	Print("Running test...")
	name, rank = UnitBuff("player", arg)
end


-- CommandBar toggle.
SLASH_TOGGLE1 = "/toggle"
SlashCmdList.TOGGLE = function (reload, gui)
	-- Toggle action bars.
	showBar1, showBar2, showBar3, showBar4 = GetActionBarToggles()
	SetActionBarToggles(showBar1, showBar2, showBar3, not showBar4)
	if reload then
		-- Hack this thread for a moment to allow for previous invocations to finish execution.
		for i = 0, 20000, 1 do
			Print(i)
		end
		-- Then reload.
		ReloadUI()
	end
end

-- Safe trinket pop.
SLASH_TRINKET1 = "/trinket"
SlashCmdList.TRINKET = function()
	if not HasFullControl() then
		UseInventoryItem(13)
	end
end

-- Main attack script.
SLASH_ATTACK1 = "/attack"
SlashCmdList.ATTACK = function()
	CombatAttack()
end

-- Attack procedure: Combat spec.
function CombatAttack()
	start, duration, enable = GetActionCooldown(Slot(5));
	-- Attempt to use Riposte.
	if IsUsableAction(Slot(5)) and duration == 0 then
		UseAction(Slot(5))
	-- Otherwise, assess melee range.
	elseif IsActionInRange(Slot(3)) == 1 then 
		if GetComboPoints() == 5 then
			-- Use eviscerate with 5 combo points.
			UseAction(Slot(4))
		else 
			-- Otherwise use Sinister Strike.
			UseAction(Slot(3))
		end
	end
	AttackOrThrow()
end

-- Determine whether to start attacking or throw.
function AttackOrThrow()
	if IsActionInRange(Slot(2)) == 1 then
		UseAction(Slot(2))
	elseif not IsCurrentAction(Slot(1)) then
		UseAction(Slot(1))
	end
end

mainHandSlot, offHandSlot = 16, 17
-- Automatic poison application algorithm.
function ApplyPoison(slot)
	-- Use poison from the specified slot in the last bag and acquire poison status.
	poisonSlot = Slot(slot)
	UseAction(poisonSlot)
	hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges = GetWeaponEnchantInfo()
	
	-- Attempt to apply poison to main hand.
	if hasMainHandEnchant ~= 1 or ShouldRenew(mainHandExpiration, mainHandCharges) then
		ApplyTo(mainHandSlot, poisonSlot)
		
	-- Attempt to apply poison to off hand.
	elseif hasOffhandEnchant ~= 1 or ShouldRenew(offHandExpiration, offHandCharges) then
		ApplyTo(offHandSlot, poisonSlot)
		
	else
		-- Cycle off hand application if both weapons have appropriate enchants.
		ApplyTo(offHandSlot, poisonSlot)
	end
end

-- Execute poison application on the specified weapon slot.
function ApplyTo(weaponSlot, poisonSlot)
	-- Apply poison.
	PickupInventoryItem(weaponSlot)
	ReplaceEnchant()
	
	-- Print poison application info.
	weapon = weaponSlot == mainHandSlot and "MAIN" or "OFF"
	count = GetActionCount(poisonSlot)
	Print("Applying poison to " .. weapon .. " hand - " .. count .. " left.")
end

minDuration, minCharges = 300, 10
-- Determine whether a poison effect should be applied under given conditions.
function ShouldRenew(expiration, charges)
	return ToSeconds(expiration) < minDuration or charges < minCharges
end


-- ============================== --
--	HELPER AND UTILITY FUNCTIONS  --
-- ============================== --

-- Calculate milliseconds to seconds.
function ToSeconds(milliseconds)
	return milliseconds / 1000;
end

-- Pass argument values 1 - 12 to get appropriate SlotID from top to bottom.
commandBarOffset = 36
function Slot(n)
	return n + commandBarOffset;
end

-- Print a message to the console, if it exists.
function Print(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
end