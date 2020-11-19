-- Server only Initialization
if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("launchDemonicSheep")
	util.AddNetworkString("controlPlayer")
	util.PrecacheSound("ttt_demonicsheep/demonicsheep_sound.wav")
	util.PrecacheSound("ttt_demonicsheep/ominous_wind.wav")
	util.PrecacheModel("models/weapons/item_ttt_demonicsheep.mdl")
	if file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
		AddCSLuaFile("terrortown/scripts/targetid_implementations.lua")
	end
end

-- Client only Initialization
if CLIENT and file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
	include("terrortown/scripts/targetid_implementations.lua")
end

-- Creates a library which handles global functions for receiving Data
demonicSheepFnc = {}

-- SWEP Initialization
SWEP.Base				= "weapon_tttbase"

SWEP.PrintName			= "Demonic Sheep"
SWEP.Author				= "ZenBreaker"
SWEP.Instructions		= "Launch the Demonic Sheep, fly to and aim at your enemies to control them!"
SWEP.Slot				= 1
SWEP.SlotPos			= 2
SWEP.Icon				= "vgui/ttt/demonicsheep/demonicsheep.png"
SWEP.EquipMenuData		= {
							type = "item_weapon",
							desc = [[
							Launch the Demonicsheep and control your enemies!
							Left-Click: Control Enemy
							Right-Click: Change Mode
							Reload: Exit Sheepmode
							]]
						}

AMMO_DEMONICSHEEP = 666

SWEP.Spawnable			= false
SWEP.AutoSpawnable		= false
SWEP.LimitedStock		= false
SWEP.AllowDrop			= true
SWEP.HoldType			= "knife"
SWEP.Kind				= WEAPON_EQUIP2
SWEP.CanBuy				= { ROLE_TRAITOR }
SWEP.WeaponID			= AMMO_DEMONICSHEEP

SWEP.DeploySpeed		= 0.01
SWEP.Primary.Ammo		= "Demonicsheep"
SWEP.Primary.Recoil		= 0
SWEP.Primary.Damage		= 0
SWEP.Primary.Delay		= 1
SWEP.Primary.Cone		= 0
SWEP.Primary.ClipSize	= 1
SWEP.Primary.ClipMax	= 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic	= true -- to enable easier enemy control

SWEP.Secondary.Automatic = true

SWEP.ViewModelFlip  	= false
SWEP.DrawCrosshair 		= false
SWEP.UseHands			= true
SWEP.ViewModelFOV		= 60
SWEP.ItemModel			= "models/weapons/item_ttt_demonicsheep.mdl"
SWEP.ViewModel			= "models/weapons/v_ttt_demonicsheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_demonicsheep.mdl"
SWEP.IronSightsPos		= Vector(2.773, 0, 0.846)
SWEP.IronSightsAng		= Vector(-0.157, 0, 0)

-- Handling serveral SWEPs in one game
local demonicSheepSwepCount = 0
local demonicSheepSweps = {}
SWEP.myId = 0

-- Sounds
sound.Add( {
name = "demonicsheep_baa",
channel = CHAN_WEAPON,
volume = 1,
level = 85,
sound = "ttt_demonicsheep/demonicsheep_sound.wav"
} )

sound.Add( {
name = "demonicsheep_wind_ominous",
channel = CHAN_STATIC,
volume = 1,
level = 80,
sound = "ttt_demonicsheep/ominous_wind.wav"
} )

sound.Add( {
name = "demonicsheep_wind_background",
channel = CHAN_STATIC,
volume = 0.3,
level = 75,
sound = "ambient/levels/canals/windmill_wind_loop1.wav"
} )

sound.Add( {
name = "demonicsheep_controlsound",
channel = CHAN_WEAPON,
volume = 0.5,
level = 70,
sound = "garrysmod/ui_click.wav"
} )

function SWEP:SetupDataTables()
	self:NetworkVar( "Entity", 0, "demonicSheepEnt" )
	self:NetworkVar( "Bool", 0, "demonicSheepEntOut" )
	self:NetworkVar( "Bool", 1, "demonicSheepEntInUse" )
	self:NetworkVar( "Int", 0, "currentControlType" )
end

-- All SWEP functions
function SWEP:Initialize()
	demonicSheepSwepCount = demonicSheepSwepCount + 1
	self.myId = demonicSheepSwepCount
	demonicSheepSweps[self.myId] = self

	self.demonicSheepEnt = nil
	self.demonicSheepEntOut = false
	self.demonicSheepEntInUse = false
	self.allowViewSwitching = false

	self.allowHolster = true
	self.holsterSheepTimer = nil
	self.holsterSheepAnimation = true
	self.holsterToWep = self

	self.nextReload = CurTime()
	self.resetSightsTimer = nil
	self.initializeSheepTimer = nil
	self.enableControlSheepTimer = nil
	self.drawLocalPlayer = false

	self.lastAngle = nil
	self.lastOrigin = nil

	-- default value for Primary Attack Animation
	self.primaryAttDuration = 1

	self.sheepToLocalOffset = nil
	self.sheepFinalOffset = nil
	self.sheepViewDistanceForward = 40
	self.sheepViewDistanceUp = 25

	-- Controlstructure should be [Player] {"Command", endTime}
	self.controlStructure = {}
	-- Available Controles are {"ControlType", duration}
	self.availableControls = {
		{"Attack", 0.5},
		{"Drop Weapon", 0.2},
		{"Holster Weapon", 0.2},
		{"Move Forward", 1},
		{"Move Backward", 1},
	}

	self.currentControlType = 1

	self:SetHoldType("pistol")

	if CLIENT then
		self:AddTTT2HUDHelp("Control Target", "Change Controlmode")
		self:AddHUDHelpLine("Switch Sheep/Player Control", Key("+reload", "R"))
	end

	if SERVER then
		net.Receive("launchDemonicSheep", function(len, ply) demonicSheepFnc.receiveSheepPosition(len, ply) end)
		net.Receive("controlPlayer", function(len, ply) demonicSheepFnc.receiveClientControlData(len, ply) end)
	end

end

function SWEP:Equip(newOwner)
	print("Equip")
end

function SWEP:Deploy()
	print("Deploy")
	-- Plays Draw_Weapon-Animation of the Sheep in your Hands
	local bPlayDrawAnimation = true
	self:playDrawWeaponAnimation(bPlayDrawAnimation)

	-- Allows general holstering
	self.allowHolster = true
	self.holsterSheepTimer = nil
	self.holsterSheepAnimation = true

	-- In case the weapon changed owner
	if IsValid(self.demonicSheepEnt) and self.demonicSheepEnt:GetOwner() ~= self:GetOwner() then
		self.demonicSheepEnt:SetOwner(self:GetOwner())
	end

	self:SetNoDraw(self.allowViewSwitching)

	-- Add a hook to be able to show your world model, when flying
	hook.Add("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer" .. tostring(self.myId), function()
		if self.shouldDrawLocalPlayer then
			return self:shouldDrawLocalPlayer()
		else
			hook.Remove("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer" .. tostring(self.myId))
			return
		end
	end)
end

function SWEP:Holster(wep)
	if not self.allowHolster then return false end

	-- Animate the Sheep and send a timer before actually holstering it
	if not self.holsterSheepTimer and self.holsterSheepAnimation then
		self:SendWeaponAnim(ACT_VM_HOLSTER)

		-- Set Timer and subtract 0.1 to holster before animation is finished
		self.holsterSheepTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration() - 0.1
		self.holsterToWep = wep
	end

	-- As long as the Animation is not done, don't allow holstering it
	if self.holsterSheepAnimation and self.holsterSheepTimer then return false end
	self.holsterSheepAnimation = true

	-- To prevent Holstering again and creating a loop 
	self.allowHolster = false
	--self.drawLocalPlayer = false
	--self.demonicSheepEntInUse = false
	return true
end

function SWEP:OnDrop()
	if not self.AllowDrop then return false end
	if IsValid(self.demonicSheepEnt) then
		self.demonicSheepEnt:SetOwner(nil)
	end

	self.demonicSheepEntInUse = false
	self.allowHolster = true
	--self.holsterSheepAnimation = false
	self.drawLocalPlayer = false
	print("Dropped")
	return
end

function SWEP:OnRemove()
	print("Removed")
	-- Allow safe Removal
	if IsValid(self.demonicSheepEnt) and SERVER then
		self.demonicSheepEnt:Remove()
		self.demonicSheepEnt = nil
	end
	self.demonicSheepEntOut = false
	self.demonicSheepEntInUse = false

	self.allowHolster = true
	--self.holsterSheepAnimation = false
	self.drawLocalPlayer = false

	return
end

function SWEP:PrimaryAttack()
	if self.demonicSheepEntOut then
		-- Control Sheep, don't launch it again and let this only be controlled by the Client
		-- As the Client could cheat, check the received Data of the Client
		if not self.demonicSheepEntInUse or SERVER then return end
		local ent = self.demonicSheepEnt

		if not IsValid(ent) or not self.demonicSheepEntInUse then return end

		local startPos, ang = self:demonicSheepView(ent)
		local endPos = ang:Forward()
		endPos:Mul(2^16)
		endPos:Add(startPos)

		local trace = util.TraceLine({
			start = startPos,
			endpos = endPos,
			mask = MASK_SHOT,
			filter = {ent}
		})

		local tracedEnt = trace.Entity
		if not IsValid(tracedEnt) or not tracedEnt:IsPlayer() then return end
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay) -- if hit entity, set a delay

		local currentControl = self.availableControls[self.currentControlType]
		self.controlStructure[tracedEnt] = {currentControl[1], CurTime() + currentControl[2]}

		-- Make sure that visually hit entities on the client are sent to the server
		if CLIENT then
			net.Start("controlPlayer")
			net.WriteInt(self.myId, 8)
			net.WriteEntity(tracedEnt)
			net.WriteInt(trace.PhysicsBone, 8)
			net.SendToServer()
		end
	else
		self:launchSheep()
		self.allowHolster = false
		if CLIENT then
			hook.Add("CreateMove", "blockPlayerActionsInLaunch"  .. tostring(self.myId), function(cmd)
				cmd:ClearMovement()
				cmd:ClearButtons()
			end)
		end

		hook.Add("Move", "blockPlayerActions"  .. tostring(self.myId), function(ply, mv)
			if self.blockPlayerActions then
				return self:blockPlayerActions(ply, mv)
			else
				hook.Remove("Move", "blockPlayerActions" .. tostring(self.myId))
			end
		end)

	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.2)

	if not IsFirstTimePredicted() then return end
	if self.demonicSheepEnt then
		self.demonicSheepEnt:EnableLoopingSounds(false)
	end
	print("Marker for Swep id " .. self.myId .. "/" .. demonicSheepSwepCount)
	self.currentControlType = 1 + math.fmod(self.currentControlType, #self.availableControls)
end

function SWEP:Reload()
	if self.nextReload >= CurTime() then return end
	if not IsFirstTimePredicted() then return end
	if not self.allowViewSwitching then return end
	self.nextReload = CurTime() + 0.3
	self.demonicSheepEntInUse = not self.demonicSheepEntInUse
	self.allowHolster = not self.allowHolster
	self.AllowDrop = not self.AllowDrop
	self.drawLocalPlayer = not self.drawLocalPlayer

	if self.lastOrigin then
		self.lastOrigin = nil
	end

	if self.lastAngle then
		self.lastAngle = nil
	end

	if self.allowHolster then
		self:SetHoldType("normal")
		-- Make sure, that the sheep doesn't fly away, when a key was pressed while switching Views
		self.demonicSheepEnt:SetMoveDirection(Vector(0, 0, 0))
	else
		self:SetHoldType("magic")
	end

end

function SWEP:Think()
	--[[ Syncing Variables
	if self.sync and self.sync <= CurTime() then
		self.sync = CurTime() + self.synchronizationInterval
		if SERVER then
			self:SetdemonicSheepEnt(self.demonicSheepEnt)
			self:SetdemonicSheepEntOut(self.demonicSheepEntOut)
			self:SetdemonicSheepEntInUse(self.demonicSheepEntInUse)
			self:SetcurrentControlType(self.currentControlType)
		elseif CLIENT then
			self.demonicSheepEnt = self:GetdemonicSheepEnt()
			self.demonicSheepEntOut = self:GetdemonicSheepEntOut()
			self.demonicSheepEntInUse = self:GetdemonicSheepEntInUse()
			self.currentControlType = self:GetcurrentControlType()
		end
	end
	--]]

	-- Switching to idle Animation after Draw Weapon Animation got played
	if not self.demonicSheepEntOut and not self.demonicSheepEntInUse and self.resetSightsTimer and self.resetSightsTimer <= CurTime() then
		self.resetSightsTimer = nil
		self:SendWeaponAnim(ACT_VM_IDLE)
		self.primaryAttDuration = self:GetViewModelSequenceDuration(ACT_VM_PRIMARYATTACK)
	end

	-- Allowing to holster after playing its Animation
	if self.holsterSheepTimer and self.holsterSheepTimer <= CurTime() then
		self.holsterSheepTimer = nil
		self.holsterSheepAnimation = false

		-- Use Input Commands for Prediction
		if CLIENT then
			input.SelectWeapon(self.holsterToWep)
		end

		-- Select Weapon on Server for other cases, i.e. switching to weapon with "use"-key
		if SERVER then
			self:GetOwner():SelectWeapon(WEPS.GetClass(self.holsterToWep))
		end
	end

	-- Initializing the demonic sheep before animation got fully played to have it available for Control
	if self.initializeSheepTimer and self.initializeSheepTimer <= CurTime() + 0.4 then
		if CLIENT then
			self.demonicSheepEnt = self:GetOwner():GetNWEntity("demonicSheepEnt")
		end

		if IsValid(self.demonicSheepEnt) then
			self.enableControlSheepTimer = self.initializeSheepTimer
			self.initializeSheepTimer = nil
			self.demonicSheepEnt:EnablePhysicsControl(true, 1.7)
			if CLIENT then
				self:sendSheepPosition()
			end
		end
	end

	-- Shortly after Initialization actually show the sheep and enable Controls
	if self.enableControlSheepTimer and self.enableControlSheepTimer <= CurTime() + 0.2 and IsValid(self.demonicSheepEnt) then
		self.enableControlSheepTimer = nil

		--self.allowHolster = true
		self.demonicSheepEntInUse = true
		self.allowViewSwitching = true

		-- To the outside you don't hold a sheep anymore and magically do stuff
		self:SetNoDraw(true)
		self:SetHoldType("magic")
		self:SendWeaponAnim(ACT_VM_IDLE)

		self.drawLocalPlayer = true

		self.demonicSheepEnt:EnableRendering(true)

		if CLIENT then
			hook.Remove("CreateMove", "blockPlayerActionsInLaunch" .. tostring(self.myId))
		end

		hook.Add("TTTModifyTargetedEntity", "demonicSheepTargetId" .. tostring(self.myId), function()
			if self.remoteTargetId then
				return self:remoteTargetId()
			else
				hook.Remove("TTTModifyTargetedEntity", "demonicSheepTargetId" .. tostring(self.myId))
				return
			end
		end)

		hook.Add("StartCommand", "readPlayerMovement" .. tostring(self.myId), function(ply, cmd)
			if self.controlSheep then
				self:controlSheep(ply, cmd)
			else
				hook.Remove("StartCommand", "readPlayerMovement" .. tostring(self.myId))
			end
		end)

		hook.Add("StartCommand", "manipulatePlayerActions" .. tostring(self.myId), function(ply, cmd)
			if self.manipulatePlayer then
				self:manipulatePlayer(ply, cmd)
			else
				hook.Remove("StartCommand", "manipulatePlayerActions" .. tostring(self.myId))
			end
		end)
	end

end

-- This controls if the viewModel should be drawn or not
function SWEP:ShouldDrawViewModel()
	return not self.allowViewSwitching
end

function SWEP:CalcView(ply, pos, ang, fov )
	if self.demonicSheepEntInUse then
		local ent = self.demonicSheepEnt
		if IsValid(ent) then
			pos, ang = self:demonicSheepView(ent)
		end
		--TODO: better follow Cam while launching the sheep
	--[[ elseif (self.initializeSheepTimer and self.initializeSheepTimer >= CurTime())
			or (self.enableControlSheepTimer and self.enableControlSheepTimer >= CurTime()) then
			pos, ang = self:followSheepAnimation(pos, ang)
	elseif self.sheepToLocalOffset then
		self.sheepToLocalOffset = nil --]]
	end
	return pos, ang, fov
end

-- This does a simple followup of the sheep while the animation runs
function SWEP:followSheepAnimation(pos, ang)
	local sheepPos = self:GetOwner():GetViewModel():GetBoneMatrix(45):GetTranslation()

	if not self.sheepToLocalOffset then
		self.sheepToLocalOffset = sheepPos - pos
		self.sheepFinalOffset = ang:Forward() * self.sheepViewDistanceForward * 2 - ang:Up() * self.sheepViewDistanceUp * 0.5
	end
	local deltaTimeLeft = (self.initializeSheepTimer or self.enableControlSheepTimer) - CurTime()
	local interpValue = deltaTimeLeft / self.primaryAttDuration
	pos = sheepPos - (self.sheepToLocalOffset * interpValue + self.sheepFinalOffset * (1 - interpValue))

	return pos, ang
end

function SWEP:demonicSheepView(ent)
	local pos = ent:GetPos()
	local ang = ent:GetAngles()
	pos = pos - ang:Forward() * self.sheepViewDistanceForward + ang:Up() * self.sheepViewDistanceUp

	return pos,ang
end

-- To show Target IDs of players this is hooked to TTTModifyTargetedEntity and calculates the entity, the sheep can see
function SWEP:remoteTargetId()
	local ent = self.demonicSheepEnt
	if not IsValid(ent) or not self.demonicSheepEntInUse then return end

	local pos, ang = self:demonicSheepView(ent)
	local dir = ang:Forward()
	filter = {ent}
	ent, distance = targetid.FindEntityAlongView(pos, dir, filter)
	return ent

end

function SWEP:playDrawWeaponAnimation(bPlayDrawAnimation)
	if bPlayDrawAnimation then
		local vModel = self:GetOwner():GetViewModel()

		self:SendWeaponAnim(ACT_VM_DRAW)

		if not self:GetOwner():IsNPC() and self:GetOwner() and vModel then
			self.resetSightsTimer = CurTime() + vModel:SequenceDuration()
		end
	else
		self:SendWeaponAnim(ACT_VM_IDLE)
	end
end

function SWEP:shouldDrawLocalPlayer()
	if self.drawLocalPlayer and LocalPlayer() == self:GetOwner() then
		return true
	else
		-- Let other addons be able to decide if it should be shown by returning nothing
		return
	end
end

function SWEP:launchSheep()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:EmitSound("demonicsheep_baa")

	if not IsFirstTimePredicted() then return end
	self.demonicSheepEntOut = true
	self.AllowDrop = false

	-- Initialize entity after animation is finished
	self.initializeSheepTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration()

	if SERVER then
		local ent = ents.Create("ent_demonicsheep")

		if (not IsValid(ent)) then return end

		local ply = self:GetOwner()
		ply:SetNWEntity("demonicSheepEnt", ent)
		self.demonicSheepEnt = ent

		ent:SetPos(ply:EyePos())
		ent:SetAngles(ply:EyeAngles())
		ent:SetOwner(ply)
		ent.demonicSheepSwep = self

		ent:Spawn()
		ent:Activate()
	end
end

-- This Section is all about Controlling the Sheep remotely and disabling Player actions

	-- This extracts the combined direction of Jumping and Crouching for going up and down
	function SWEP:getUpMove(cmd)
		local jump = cmd:KeyDown(IN_JUMP)
		local crouch = cmd:KeyDown(IN_DUCK)

		return ((jump and 1) or 0) + ((crouch and -1) or 0)
	end

	-- Control the sheep with your mouse and movekeys
	-- Server only, because prediction for the sheep is still broken
	function SWEP:controlSheep(ply, cmd)
		if not SERVER or not ply:IsValid() then return end
		local wep = ply:GetActiveWeapon()

		if not IsValid(wep) or wep ~= self or not self.demonicSheepEntInUse then return end
		local ent = self.demonicSheepEnt

		-- Handle View Rotations
		local mouseX = cmd:GetMouseX()
		local mouseY = cmd:GetMouseY()
		local newAngle = ent:GetAngles()
		newAngle:RotateAroundAxis(Vector(0, 0, -1), mouseX * 360.0 / 8000.0)
		newAngle.pitch = math.Clamp(newAngle.pitch + mouseY * 360.0 / 8000.0, -89, 89)
		newAngle.roll = 0
		ent:SetAngles(newAngle)

		-- Handle Sheep Movement
		local forwardMove = cmd:GetForwardMove()
		local sideMove = cmd:GetSideMove()
		local upMove = self:getUpMove(cmd) * 10000
		local sprintMove = (cmd:KeyDown(IN_SPEED) and 1.5) or 1
		local moveDirection = newAngle:Forward() * forwardMove + newAngle:Right() * sideMove + newAngle:Up() * upMove
		moveDirection:Normalize()
		ent:SetMoveDirection(moveDirection * sprintMove)
	end

	-- By Hooking to the Move-Hook we disable the players movement and him looking around
	function SWEP:blockPlayerActions(ply, mv)
		if not ply:IsValid() then return end
		local wep = ply:GetActiveWeapon()

		if not IsValid(wep) or wep ~= self or not self.demonicSheepEntInUse then return end

		if not self.lastAngle then
			self.lastAngle = mv:GetAngles()
		end

		-- Set MoveDataVelocity to 0, this disables all other physics interactions
		mv:SetVelocity(Vector(0,0,0))
		ply:SetEyeAngles(wep.lastAngle)

		-- Return true to block defaul Calculation of Movement-Data and stop Animations
		return true
	end
--

function SWEP:manipulatePlayer(ply, cmd)
	if not IsValid(ply) or not self.controlStructure[ply] or not IsValid(self:GetOwner()) then return end
	local wep = self:GetOwner():GetActiveWeapon()

	if not IsValid(wep) or wep ~= self or not self.demonicSheepEntInUse then return end

	local controlList = self.controlStructure[ply]
	if controlList[2]  >= CurTime() then
		local controlKey = controlList[1]
		if controlKey == "Attack" then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		elseif controlKey == "Drop Weapon" then
			if SERVER and #ply:GetWeapons() > 3 and ply:GetActiveWeapon().AllowDrop then
				ply:DropWeapon() -- only available on Server
			else
				self.controlStructure[ply] = nil
			end
		elseif controlKey == "Holster Weapon" then
			local changeToSwep = ply:GetWeapons()[3] -- 3 Should be Holstered in TTT if not changed
			if IsValid(changeToSwep) then
				if CLIENT then
					input.SelectWeapon(changeToSwep)
				end

				if SERVER then
					ply:SelectWeapon(WEPS.GetClass(changeToSwep))
				end
			end
			self.controlStructure[ply] = nil
		elseif controlKey == "Move Forward" then
			cmd:SetButtons(cmd:GetButtons() + IN_FORWARD)
			cmd:SetForwardMove(cmd:GetForwardMove() + 9950)
		elseif controlKey == "Move Backward" then
			cmd:SetButtons(cmd:GetButtons() + IN_BACK)
			cmd:SetForwardMove(cmd:GetForwardMove() - 9950)
		end
	else
		self.controlStructure[ply] = nil
	end

end

function demonicSheepFnc.receiveClientControlData(len, ply)
	if len and len < 1 then
		print("ERROR: Empty Message received by " .. ply .. " for PrimaryAttack Sheep Control in SWEP:receiveClientControlData")
		return
	end
	local entityId = net.ReadInt(8)
	if not entityId or entityId > demonicSheepSwepCount then return end
	local swep = demonicSheepSweps[entityId]
	if not IsValid(ply) or not IsValid(swep) or ply ~= swep:GetOwner() then return end

	local tracedEnt = net.ReadEntity()
	if not IsValid(tracedEnt) or not tracedEnt:IsPlayer() then return end

	-- Make sure, the client didn't send a false entity which can't be controlled by the Sheep
	local physBone = net.ReadInt(8)
	local physBoneCount = tracedEnt:GetBoneCount()
	if physBone > physBoneCount then return end

	local bone = tracedEnt:TranslatePhysBoneToBone(physBone)
	local bonePos = tracedEnt:GetBonePosition(bone)

	local startPos = swep:demonicSheepView(swep.demonicSheepEnt)
	local trace = util.TraceLine({
		start = startPos,
		endpos = bonePos,
		mask = MASK_SHOT,
		filter = {swep.demonicSheepEnt}
	})

	if not IsValid(trace.Entity) and trace.Entity ~= tracedEnt then return end
	swep:SetNextPrimaryFire(CurTime() + swep.Primary.Delay)

	-- Finally overwrite controls of the trace Entity
	local currentControl = swep.availableControls[swep.currentControlType]
	swep.controlStructure[tracedEnt] = {currentControl[1], CurTime() + currentControl[2]}

	-- Play the controlsound for all
	swep:EmitSound("demonicsheep_controlsound")
end

-- This Section is for the sheep Position inside the Animation, when the sheep is launched

	-- As Viewmodels are only available to the player, we send the position of the sheep in the animation frame to the server
	function SWEP:sendSheepPosition()
		-- Bone number 45 is the Demonicsheep_Breast 
		local pos = self:GetOwner():GetViewModel():GetBoneMatrix(45):GetTranslation()
		net.Start("launchDemonicSheep")
		net.WriteInt(self.myId, 8)
		net.WriteVector(pos)
		net.SendToServer()

		-- Set Position predictionwise
		local ent = self.demonicSheepEnt
		ent:SetPos(pos)
		ent:SetAngles(self:GetOwner():EyeAngles())
		self:SendWeaponAnim(ACT_VM_IDLE)
	end

	-- Here we receive the Sheep's Position, that got sent by the client, containing the animationsheep's Position
	function demonicSheepFnc.receiveSheepPosition(len, ply)
		if len and len < 1 then
			print("ERROR: Empty Message received by " .. ply .. " for initializeSheepTimer in SWEP:receiveViewModelDemonicSheepPosition")
			return
		end
		local entityId = net.ReadInt(8)
		if not entityId or entityId > demonicSheepSwepCount then return end

		local swep = demonicSheepSweps[entityId]
		if not IsValid(ply) or not IsValid(swep) or ply ~= swep:GetOwner() then return end

		local pos = net.ReadVector()
		local ent = swep.demonicSheepEnt

		if (not IsValid(ent)) then return end

		ent:SetPos(pos)
		ent:SetAngles(ply:EyeAngles())
	end
--

-- This is a Helper-Function to get the Sequence Duration of the Viewmodel with the input sequence ID
function SWEP:GetViewModelSequenceDuration(seqid)
	local vModel = self:GetOwner():GetViewModel()
	local seq = vModel:SelectWeightedSequence(seqid)
	return vModel:SequenceDuration(seq) or 0
end

-- OLD Code that could be helpful to get some stuff done
--[[
hook.Add("PlayerUse", "demonicsheep_PickupItem", function(ply, entity)
		if IsValid(ply) and IsValid(entity) and entity:GetModel() == "models/weapons/item_ttt_demonicsheep.mdl" and ply:CanCarryType(WEAPON_EQUIP2) then
			ply:Give("weapon_ttt_demonicsheep")

			local wep = ply:GetWeapon("weapon_ttt_demonicsheep")

			entity:Remove()
			return false
		end
end)

function SWEP:Initialize()
	local function demonicsheep_ObserverView( ply, pos, angles, fov )
			if (not IsValid(ply) or ply:GetNWBool("Spectatedemonicsheep") ~= true or not IsValid(ply:GetNWEntity("Spectating_demonicsheep"))) then return end
			local demonicsheep_ent = ply:GetNWEntity("Spectating_demonicsheep")
			local view = {}
			local minifiedViewOrigin = demonicsheep_ent:GetPos() -( angles:Forward() * 50 + Vector(0, 0, -10))
			local magnifiedViewOrigin = demonicsheep_ent:GetPos() -( angles:Forward() * 100 + Vector(0, 0, -45))
			local interpolValue = 1
			if demonicsheep_ent.MinifiedStart then
				interpolValue = CurTime() - demonicsheep_ent.MinifiedStart
			end

			if demonicsheep_ent.Minified then
				if (interpolValue < 1) then
					view.origin = minifiedViewOrigin * interpolValue + magnifiedViewOrigin * (1- interpolValue)
				else
					view.origin = minifiedViewOrigin
				end
			else
				if (interpolValue < 1) then
					view.origin = magnifiedViewOrigin * interpolValue + minifiedViewOrigin * (1- interpolValue)
				else
					view.origin = magnifiedViewOrigin
				end
			end

			view.angles = angles
			view.fov = fov
			view.drawviewer = true

			return view
	end

	hook.Add( "CalcView", "demonicsheep_ObserverView", demonicsheep_ObserverView )

	hook.Add("Think", "demonicsheep_LetPlayerObserve", function()
		for k, v in pairs( player.GetAll() ) do
			local observerTarget = v:GetObserverTarget()
			if (observerTarget ~= nil and IsValid(observerTarget) and observerTarget:IsPlayer() and observerTarget:Alive() and IsValid(observerTarget:GetActiveWeapon()) and observerTarget:GetActiveWeapon():GetClass() == "weapon_ttt_demonicsheep") then
				local demonicsheep_entity = observerTarget:GetNWEntity("demonicsheep_entity")
				if (IsValid(demonicsheep_entity) and SERVER) then
					--v:SpectateEntity(demonicsheep_entity)
					--v:Spectate(OBS_MODE_CHASE)
					v:SetNWBool("Spectatedemonicsheep",true)
					v:SetNWEntity("Spectating_demonicsheep", demonicsheep_entity)
				else
					--v:SetNWBool("Spectatedemonicsheep",false)
				end
			else
				v:SetNWBool("Spectatedemonicsheep",false)
			end
		end
	end)
end

function SWEP:OnDrop()
	if CLIENT then return end

	ent_item = ents.Create("prop_physics")

	ent_item:SetModel("models/weapons/item_ttt_demonicsheep.mdl")
	ent_item:SetPos(self:GetPos() + self.LastOwner:GetAimVector() * 10)
	ent_item:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	ent_item:Spawn()
	local phys = ent_item:GetPhysicsObject()
	phys:ApplyForceCenter(self.LastOwner:GetPhysicsObject():GetVelocity() * 2 + self.LastOwner:GetAimVector() * 400 + Vector(0, 0, 100))
	phys:AddAngleVelocity(self.LastOwner:GetAimVector() * 100)
	self:Remove()
end
--]]