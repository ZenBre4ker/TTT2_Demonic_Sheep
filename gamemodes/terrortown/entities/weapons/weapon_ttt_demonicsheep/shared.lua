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

SWEP.Spawnable			= false
SWEP.AutoSpawnable		= false
SWEP.LimitedStock		= true
SWEP.AllowDrop			= true
SWEP.HoldType			= "knife"
SWEP.Kind				= WEAPON_EQUIP2
SWEP.CanBuy				= { ROLE_TRAITOR }

SWEP.DeploySpeed		= 0.01
SWEP.Primary.Ammo		= "Demonicsheep"
SWEP.Primary.Recoil		= 0
SWEP.Primary.Damage		= 0
SWEP.Primary.Delay		= 0.0
SWEP.Primary.Cone		= 0
SWEP.Primary.ClipSize	= 1
SWEP.Primary.ClipMax	= 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic	= false

SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay	= 5

SWEP.ViewModelFlip  	= false
SWEP.DrawCrosshair 		= false
SWEP.UseHands			= true
SWEP.ViewModelFOV		= 60
SWEP.ViewModel			= "models/weapons/v_ttt_demonicsheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_demonicsheep.mdl"
SWEP.IronSightsPos		= Vector(2.773, 0, 0.846)
SWEP.IronSightsAng		= Vector(-0.157, 0, 0)

-- Server only Initialization
if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("launchDemonicSheep")
	if file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
		AddCSLuaFile("terrortown/scripts/targetid_implementations.lua")
	end
end

-- Client only Initialization
if CLIENT and file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
	include("terrortown/scripts/targetid_implementations.lua")
end

-- All local used variables
local demonicSheepSwep

-- All SWEP functions
function SWEP:Initialize()
	demonicSheepSwep = self

	self.demonicSheepEnt = nil
	self.demonicSheepEntOut = false
	self.demonicSheepEntInUse = false
	self.allowViewSwitching = false

	self.allowHolster = true
	self.holsterSheepTimer = nil
	self.holsterSheepAnimation = true
	self.holsterToWep = self
	self.isForceHolstered = false

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

	-- Network Hold Type to all
	self:SetHoldType("pistol")
	if SERVER then
		net.Receive("launchDemonicSheep", function(len, ply) self:receiveSheepPosition(len, ply) end)
	end

end

function SWEP:Deploy()
	-- Plays Draw_Weapon-Animation of the Sheep in your Hands
	local bPlayDrawAnimation = true
	self:playDrawWeaponAnimation(bPlayDrawAnimation)

	-- Allows general holstering
	self.allowHolster = true

	self.lastOwner = self:GetOwner()

	-- Add a hook to be able to show your world model, when flying
	hook.Add("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer", function()
		if self.shouldDrawLocalPlayer then
			return self:shouldDrawLocalPlayer()
		else
			hook.Remove("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer")
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
	return true
end

function SWEP:OnDrop()
	return
end

function SWEP:OnRemove()
	return
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 1)

	if self.demonicSheepEntOut then
	-- Control Sheep, don't launch it again
	else
		self:launchSheep()
		self.allowHolster = false
		if CLIENT then
			hook.Add("CreateMove", "blockPlayerActionsInLaunch", function(cmd)
				cmd:ClearMovement()
				cmd:ClearButtons()
			end)
		end

		hook.Add("Move", "blockPlayerActions", function(ply, mv)
			if self.blockPlayerActions then
				return self:blockPlayerActions(ply, mv)
			else
				hook.Remove("Move", "blockPlayerActions")
			end
		end)

	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 1)

	if not IsFirstTimePredicted() then return end
	print("\nMarker.")
	if not self.allowViewSwitching then return end
	self.demonicSheepEntInUse = not self.demonicSheepEntInUse
	self.allowHolster = not self.allowHolster
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

function SWEP:Reload()

end

function SWEP:Think()
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
	if self.initializeSheepTimer and self.initializeSheepTimer <= CurTime() + 0.2 then
		if CLIENT then
			self.demonicSheepEnt = self:GetOwner():GetNWEntity("demonicSheepEnt")
		end

		if IsValid(self.demonicSheepEnt) then
			self.initializeSheepTimer = nil
			self.enableControlSheepTimer = CurTime() + 0.2
			self.demonicSheepEnt:EnablePhysicsControl(true, 1.7)
			if CLIENT then
				self:sendSheepPosition()
			end
		end
	end

	-- Shortly after Initialization actually show the sheep and enable Controls
	if self.enableControlSheepTimer and self.enableControlSheepTimer <= CurTime() and IsValid(self.demonicSheepEnt) then
		self.enableControlSheepTimer = nil

		self.demonicSheepEntInUse = true
		self.allowViewSwitching = true

		-- To the outside you don't hold a sheep anymore and magically do stuff
		-- Clientside you see the sheep to remember you, that you control the sheep
		self:SetNoDraw(true)
		self:SetHoldType("magic")
		self:SendWeaponAnim(ACT_VM_IDLE)

		self.drawLocalPlayer = true

		self.demonicSheepEnt:EnableRendering(true)

		if CLIENT then
			hook.Remove("CreateMove", "blockPlayerActionsInLaunch")
		end

		hook.Add("TTTModifyTargetedEntity", "demonicSheepTargetId", function()
			if self.remoteTargetId then
				return self:remoteTargetId()
			else
				hook.Remove("TTTModifyTargetedEntity", "demonicSheepTargetId")
				return
			end
		end)

		hook.Add("StartCommand", "readPlayerMovement", function(ply, cmd)
			if self.controlSheep then
				self:controlSheep(ply, cmd)
			else
				hook.Remove("StartCommand", "readPlayerMovement")
			end
		end)
	end

end

function SWEP:ShouldDrawViewModel()
	if self.allowViewSwitching then
		return false
	else
		return true
	end
end

function SWEP:CalcView(ply, pos, ang, fov )
	if self.demonicSheepEntInUse then
		local ent = self.demonicSheepEnt
		if IsValid(ent) then
			pos, ang = self:demonicSheepView(ent)
		end
	elseif (self.initializeSheepTimer and self.initializeSheepTimer >= CurTime())
			or (self.enableControlSheepTimer and self.enableControlSheepTimer >= CurTime()) then
			pos, ang = self:followSheepAnimation(pos, ang)
	elseif self.sheepToLocalOffset then
		self.sheepToLocalOffset = nil
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
	if self.drawLocalPlayer then
		return true
	else
		-- Let other addons be able to decide if it should be shown
		return
	end
end

function SWEP:launchSheep()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if not IsFirstTimePredicted() then return end
	self.demonicSheepEntOut = true

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

		ent:Spawn()
		ent:Activate()

	end
end

---
-- This Section is all about Controlling the Sheep remotely and disabling Player actions

function SWEP:getUpMove(cmd)
	local jump = cmd:KeyDown(IN_JUMP)
	local crouch = cmd:KeyDown(IN_DUCK)

	return ((jump and 1) or 0) + ((crouch and -1) or 0)
end

-- Control the sheep with your mouse and movekeys
-- Server only, because prediction for the sheep is still broken
function SWEP:controlSheep(ply, cmd)
	local wep = ply:GetActiveWeapon()
	if SERVER and ply:IsValid() and IsValid(wep) and wep:GetClass() == "weapon_ttt_demonicsheep" and self.demonicSheepEntInUse then
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
end

-- By Hooking to the Move-Hook we disable the players movement and him looking around
function SWEP:blockPlayerActions(ply, mv)
	local wep = ply:GetActiveWeapon()
	if ply:IsValid() and IsValid(wep) and wep:GetClass() == "weapon_ttt_demonicsheep" and self.demonicSheepEntInUse then

		if not wep.lastAngle then
			self.lastAngle = mv:GetAngles()
		end

		-- Set MoveDataVelocity to 0, this disables all other physics interactions
		mv:SetVelocity(Vector(0,0,0))
		ply:SetEyeAngles(self.lastAngle)

		-- Return true to block defaul Calculation of Movement-Data and stop Animations
		return true
	end
	return
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

-- As Viewmodels are only available to the player, we send the position of the sheep in the animation frame to the server
function SWEP:sendSheepPosition()
	-- Bone number 45 is the Demonicsheep_Breast 
	local pos = self:GetOwner():GetViewModel():GetBoneMatrix(45):GetTranslation()
	net.Start("launchDemonicSheep")
	net.WriteVector(pos)
	net.SendToServer()

	-- Set Position predictionwise
	local ent = self.demonicSheepEnt
	ent:SetPos(pos)
	ent:SetAngles(self:GetOwner():EyeAngles())
	self:SendWeaponAnim(ACT_VM_IDLE)
end

-- Here we receive the Sheep's Position, that got sent by the client, containing the animationsheep's Position
function SWEP:receiveSheepPosition(len, ply)
	if len and len < 1 then
		print("ERROR: Empty Message received by " .. ply .. " for initializeSheepTimer in SWEP:receiveViewModelDemonicSheepPosition")
		return
	end
	local pos = net.ReadVector()
	local ent = self.demonicSheepEnt

	if (not IsValid(ent)) then return end

	ent:SetPos(pos)
	ent:SetAngles(ply:EyeAngles())
end

-- This is a Helper-Function to get the Sequence Duration of the Viewmodel with the input sequence ID
function SWEP:GetViewModelSequenceDuration(seqid)
	local vModel = self:GetOwner():GetViewModel()
	local seq = vModel:SelectWeightedSequence(seqid)
	return  vModel:SequenceDuration(seq) or 0
end
--[[

---
--Some Feature-Examples:
---

hook.Add("StartCommand", "InterceptMovement", function(ply, cmd)
	if ply:IsValid() and ply:GetActiveWeapon():GetClass() == "weapon_ttt_demonicsheep" then
		local mouseX = cmd:GetMouseX()
		mouseXMoves = mouseXMoves + mouseX
		if useAlternateView then
			local newAngle = cmd:GetViewAngles()
			newAngle:RotateAroundAxis(Vector(0,0,-1), mouseX * 360.0 / 16000.0)
			-- cmd:SetViewAngles(newAngle)
			if mouseAnglesStart then
				cmd:SetViewAngles(mouseAnglesStart)
			end
		end
	end
end)

if CLIENT then
	hook.Add("FinishMove", "InterceptMovement2", function(ply, mv)
		if ply:IsValid() and  ply:GetActiveWeapon():GetClass() == "weapon_ttt_demonicsheep" then
			if not mouseAnglesStart then
				mouseAnglesStart = mv:GetAngles()
			end
			mouseAnglesCurrent = mv:GetAngles()
		end
	end)
end

---
-- End of Feature Examples
---

if SERVER then
	AddCSLuaFile()
	if file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
		AddCSLuaFile("terrortown/scripts/targetid_implementations.lua")
	end
	util.AddNetworkString("InitializedDemonicSheep")
end

if CLIENT and file.Exists("terrortown/scripts/targetid_implementations.lua", "LUA") then
	include("terrortown/scripts/targetid_implementations.lua")
end

local DemonicSheepSwep
local Demonicsheep_out = false
--SWEP.Demonicsheep_out	= false
local skipAnimationConV = GetConVar("ttt_DemnShp_SkipAnimation")
local demnShpDurationConV = GetConVar("ttt_DemnShp_duration")

function TTT2_Simple_TargetId_Implementation(ent, distance)
	local client = LocalPlayer()
	local demonicsheep = client:GetActiveWeapon().Ent_demonicsheep
	if IsValid(demonicsheep) then
		local pos = Vector(0,0,0)
		local viewAngle = client:EyeAngles()
		pos, viewAngle = demonicsheep_View(client:GetActiveWeapon(), pos, viewAngle)
		local dir = client:GetAimVector()
		filter = {demonicsheep}
		ent, distance = targetid.FindEntityAlongView(pos, dir, filter)
	end
	return ent

end

--Temporary TargetId_Implementations until better solution integrated in TTT2 is found
hook.Add("TTTModifyTargetedEntity", "demonicsheep_TargetID", TTT2_Simple_TargetId_Implementation)
print("\n------------TTT2 Simple HudDrawTargetID-----------\n")

hook.Add("SetupPlayerVisibility", "demonicsheep_AddToPVS", function(ply, viewent)
	if IsValid(ply) and IsValid(ply:GetNWEntity("demonicsheep_entity")) then
		local sheep = ply:GetNWEntity("demonicsheep_entity")
		AddOriginToPVS( sheep:GetPos() )
	end
end)

hook.Add("PlayerUse", "demonicsheep_PickupItem", function(ply, entity)
		if IsValid(ply) and IsValid(entity) and entity:GetModel() == "models/weapons/item_ttt_demonicsheep.mdl" and ply:CanCarryType(WEAPON_EQUIP2) then
			ply:Give("weapon_ttt_demonicsheep")

			local wep = ply:GetWeapon("weapon_ttt_demonicsheep")

			entity:Remove()
			return false
		end
end)

function SWEP:Initialize()
	DemonicSheepSwep = self
	Demonicsheep_out = false

	self:SetWeaponHoldType("knife")
	self.DontHolster = false
	self.Ent_demonicsheep = nil
	self.CanFly = false
	self.IsFlying = false
	self.CancelSound = false
	self.SheepStartTime = -1

	self.isBoosting = false
	self.BoostPressed = false

	self.Boost = 100
	self.MaxBoost = 100

	self.Minified = false
	self.LastSizeChange = 0

	timer.Create("demonicsheepBoost" .. tostring(self), 0.05, 0, function()
		if IsValid(self.Ent_demonicsheep) and self.SheepStartTime >= 0 then
			if self.isBoosting then
				self.Boost = math.max(self.Boost - 2, 0)
			else
				self.Boost = math.min(self.Boost + 1, self.MaxBoost)
			end
		end
	end)

	sound.Add( {
	name = "demonicsheep_wind",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	sound = "ambient/levels/canals/windmill_wind_loop1.wav"
	} )


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


	if CLIENT then
		print("DemonicSHeep on client initialized.")
		surface.CreateFont("demonicsheep_Font",   {font = "Trebuchet24",size = 18,weight = 750})
	end
end

function SWEP:PrimaryAttack()
	if not Demonicsheep_out then
		Demonicsheep_out = true
		self.AllowDrop = false

		self:EmitSound("ttt_demonicsheep/sheep_sound.wav")

		local VModel = self.Owner:GetViewModel()
		local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_PRIMARYATTACK )
		local sheepAnimationDuration = VModel:SequenceDuration(EnumToSeq)
		VModel:SendViewModelMatchingSequence(EnumToSeq)

		if skipAnimationConV:GetBool() then
			initializeDemonicSheep(self)
		else
			--duration times 0.5, because the server seems to think that everything takes double the time.... (BUG or Setting?)
			timer.Simple(sheepAnimationDuration * 0.5, function() initializeDemonicSheep(DemonicSheepSwep) end)
		end
	elseif IsValid(self.Ent_demonicsheep) then
		self.Ent_demonicsheep:Explode()
	end
end

function initializeDemonicSheep(slf)
	slf.Owner:SetNWBool("demonicsheep_removed", false)
	slf.Owner:DrawViewModel(false)
	slf:SetNoDraw(true)
	slf.SheepStartTime = CurTime()
	slf.DontHolster = true

	if CLIENT then
		net.Receive("InitializedDemonicSheep",function()
			local slf = DemonicSheepSwep
			local ent = net.ReadEntity()
			if not IsValid(ent) then
				ent = slf.Owner:GetNWEntity("demonicsheep_entity")
			end
			slf.Ent_demonicsheep = ent
			slf.Owner.demonicsheep = slf
			ent.CorrespondingWeapon = slf
			hook.Add( "CreateMove", "demonicsheep_ProcessMovement", demonicsheep_ProcessMovement )
			local function demonicsheep_ShowLocalPlayer() return true end
			hook.Add("ShouldDrawLocalPlayer","demonicsheep_ShowLocalPlayer",demonicsheep_ShowLocalPlayer)
		end)
	end

	--The rest is only done on the server
	if SERVER then

		local ent = placedemonicsheep(slf)
		slf.Ent_demonicsheep = ent
		ent.CorrespondingWeapon = slf

		hook.Add( "SetupPlayerVisibility", "AddRTCamera", function( pPlayer, pViewEntity )
			-- Adds any view entity
			if ( pViewEntity:IsValid() ) then
				AddOriginToPVS( pViewEntity:GetPos() )
			end
		end)
	end
	return
end

function placedemonicsheep(slf)
	ply = slf:GetOwner()
	if ( CLIENT ) then return end

	local ent = ents.Create( "ent_demonicsheep" )

	if ( not IsValid( ent ) ) then return end

	local viewVector = ply:GetEyeTrace().Normal
	eyeAngles = ply:EyeAngles()

	local duckOffset = Vector(0, 0, 0)
	if ply:Crouching() then duckOffset = ply:GetViewOffsetDucked() end

	ent:SetPos(ply:EyePos() + viewVector * 50 + duckOffset)
	ent:SetAngles(eyeAngles)

	ent.Owner = ply
	if IsValid(ply) and IsValid(ent) then
		ply.demonicsheep = slf
	end
	ent:Spawn()
	ent:Activate()

	ply:SetNWEntity("demonicsheep_entity", ent)

	local phys = ent:GetPhysicsObject()
	if ( not IsValid( phys ) ) then ent:Remove() return end

	return ent

end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end
	if not IsValid(self) or not IsValid(self.Ent_demonicsheep) or not IsValid(self.Owner) then return end
	self.Ent_demonicsheep.Minify = true
	self.Minified = not self.Minified
	self.LastSizeChange = CurTime()
	self:SetNextSecondaryFire(CurTime() + 5)
end

function SWEP:Reload()
	if not Demonicsheep_out then return end

	if self.Boost > 33 or (self.Boost > 0 and self.isBoosting )  then
		self.Ent_demonicsheep.Boost = true
		self.BoostPressed = true
	end
end

function SWEP:Think()

	if not self.isBoosting and self.BoostPressed then
		self.isBoosting = true
		self.Ent_demonicsheep:EmitSound("ttt_demonicsheep/sheep_sound.wav")
		if SERVER then
			local startWidth = 0.8
			local endWidth = 0
			if IsValid(self.Ent_demonicsheep) then
				self.TrailLeft = util.SpriteTrail( self.Ent_demonicsheep.TrailLeft, 0, Color(255,255,255), false, startWidth, endWidth, 0.07, 1 / ( startWidth + endWidth ) * 0.5, "trails/smoke.vmt" )
				self.TrailRight = util.SpriteTrail( self.Ent_demonicsheep.TrailRight, 0, Color(255,255,255), false, startWidth, endWidth, 0.07, 1 / ( startWidth + endWidth ) * 0.5, "trails/smoke.vmt" )
				self.Ent_demonicsheep:SetPlaybackRate(1.6)
			end
		end
	elseif not self.BoostPressed then
		self.isBoosting = false
		if IsValid(self.TrailLeft) then self.TrailLeft:Remove() end
		if IsValid(self.TrailRight) then self.TrailRight:Remove() end
		if IsValid(self.Ent_demonicsheep) then self.Ent_demonicsheep:SetPlaybackRate(1.0) end
	end
	self.BoostPressed = false

	if Demonicsheep_out and (CurTime() - self.SheepStartTime) >= demnShpDurationConV:GetInt() and IsValid(self.Ent_demonicsheep) then
		self.Ent_demonicsheep:Explode()
	end

end

function demonicsheep_ProcessMovement(cmd)
	slf = DemonicSheepSwep
	if not IsValid(slf.Ent_demonicsheep) or not IsValid(slf) or not IsValid(slf.Owner) or slf.Owner:GetNWBool("demonicsheep_removed") then return end

	--Process Commands
	--
	--Clear Commands before sending to Server
	--While flying, the character shouldn't be able to move.
	cmd:ClearMovement()
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_DUCK)
	cmd:RemoveKey(IN_USE)
end

function SWEP:CalcView(ply, pos, ang, fov )
	if not IsValid(self) or not IsValid(self.Ent_demonicsheep) or not self.Ent_demonicsheep.isInitialized or not IsValid(self.Owner) or ply ~= self.Owner or LocalPlayer():GetNWBool("demonicsheep_removed") then return end
	if not self.CancelSound then self:EmitSound("demonicsheep_wind") end
	pos, ang = demonicsheep_View(self,pos,ang)
	return pos, ang, fov
end

function demonicsheep_View(slf,pos,ang)
	local minifiedViewOrigin = slf.Ent_demonicsheep:GetPos() - (ang:Forward() * 50 + Vector(0, 0, -10))
	local magnifiedViewOrigin = slf.Ent_demonicsheep:GetPos() - (ang:Forward() * 100 + Vector(0, 0, -45))
	local interpolValue = CurTime() - slf.Ent_demonicsheep.MinifiedStart
	local isMinified = slf.Ent_demonicsheep.Minified

	if isMinified then
		if (interpolValue < 1) then
			pos = minifiedViewOrigin * interpolValue + magnifiedViewOrigin * (1- interpolValue)
		else
			pos = minifiedViewOrigin
		end
	else
		if (interpolValue < 1) then
			pos = magnifiedViewOrigin * interpolValue + minifiedViewOrigin * (1- interpolValue)
		else
			pos = magnifiedViewOrigin
		end
	end
	return pos, ang
end

function SWEP:Holster()
	if not IsValid(self.LastOwner) then return false end
	return not self.DontHolster or self.LastOwner:GetNWBool("demonicsheep_removed")
end

function SWEP:Deploy()
	local VModel = self.Owner:GetViewModel()
	local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_IDLE )

	VModel:SendViewModelMatchingSequence( EnumToSeq )

	--local VModel = self.Owner:GetViewModel()
	--self:SetPlaybackRate( 0.01 )
	--VModel:SendViewModelMatchingSequence( EnumToSeq )

	--self.Weapon:SetPlaybackRate( 0.01 )
	self.LastOwner = self.Owner
	--self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
	--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
end

function SWEP:OnDrop()
	--print(self.Owner)
	--print(self.LastOwner)
	--self.WorldModel = "models/weapons/item_ttt_demonicsheep.mdl"
	--self:SetModel("models/weapons/item_ttt_demonicsheep.mdl")

	if self.SheepStartTime >= 0 then
		self.CancelSound = true
		self:StopSound("demonicsheep_wind")

		if SERVER then self:Remove() end
		return
	end

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

function SWEP:OnRemove()
	--hook.Remove("PlayerUse", "demonicsheep_PickupItem")
	hook.Remove("CreateMove", "demonicsheep_ProcessMovement")
	hook.Remove("CalcView", "demonicsheep_View")
	hook.Remove("ShouldDrawLocalPlayer","demonicsheep_ShowLocalPlayer")
	self.CancelSound = true
	self:StopSound("demonicsheep_wind")
	if not IsValid(self.Owner) then return end
	local newWeapon = self.Owner:GetWeapons()[2]
	if (SERVER and IsValid(newWeapon)) then
		self.Owner:SelectWeapon(newWeapon:GetClass())
	end
	timer.Remove("demonicsheepBoost" .. tostring(self))
end

local function ShadowedText(text, font, x, y, color, xalign, yalign)

	draw.SimpleText(text, font, x + 2, y + 2, COLOR_BLACK, xalign, yalign)

	draw.SimpleText(text, font, x, y, color, xalign, yalign)
end

--]]