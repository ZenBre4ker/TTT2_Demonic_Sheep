-- Server only Initialization
if SERVER then
	AddCSLuaFile()

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
AMMO_DEMONICSHEEP 		= 666

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
SWEP.LimitedStock		= false
SWEP.AllowDrop			= true
SWEP.HoldType			= "pistol"
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
SWEP.ViewModel			= "models/weapons/v_ttt_demonicsheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_demonicsheep.mdl"
SWEP.IronSightsPos		= Vector(2.773, 0, 0.846)
SWEP.IronSightsAng		= Vector(-0.157, 0, 0)

-- Custom SWEP Variables referenced with self
SWEP.ItemModel			= "models/weapons/item_ttt_demonicsheep.mdl"

SWEP.nextReload = 0
SWEP.resetSightsTimer = nil
SWEP.initializeSheepTimer = nil
SWEP.enableControlSheepTimer = nil
SWEP.holsterSheepTimer = nil

SWEP.primaryAttDuration = 1

SWEP.sheepViewDistanceForward = 40
SWEP.sheepViewDistanceUp = 25

-- Available Controles are {"ControlType", duration}
SWEP.availableControls = {
	{"Attack", 0.5},
	{"Drop Weapon", 0.2},
	{"Holster Weapon", 0.2},
	{"Move Forward", 1},
	{"Move Backward", 1},
}

-- Handling serveral SWEPs in one game
local demonicSheepSwepCount = 0

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
	self:NetworkVar("Entity", 0, "demonicSheepEnt")
	self:NetworkVar("Entity", 1, "holsterToWep")
	self:NetworkVar("Entity", 2, "lastOwner")
	self:NetworkVar("Entity", 3, "itemDrop")
	self:NetworkVar("Bool", 0, "demonicSheepEntOut")
	self:NetworkVar("Bool", 1, "demonicSheepEntInUse")
	self:NetworkVar("Bool", 2, "allowViewSwitching")
	self:NetworkVar("Bool", 3, "allowHolster")
	self:NetworkVar("Bool", 4, "holsterSheepAnimation")
	self:NetworkVar("Bool", 5, "allowDrop")
	self:NetworkVar("Bool", 6, "lastAngleSet")
	self:NetworkVar("Bool", 7, "drawWorldModel")
	self:NetworkVar("Int", 0, "myId")
	self:NetworkVar("Int", 1, "currentControlType")
	self:NetworkVar("Angle", 0, "lastAngle")
end

-- All SWEP functions
function SWEP:Initialize()
	demonicSheepSwepCount = demonicSheepSwepCount + 1

	self:SetNetworkedVariables()

	if CLIENT then
		self:AddTTT2HUDHelp("Control Target", "Change Controlmode")
		self:AddHUDHelpLine("Switch Sheep/Player Control", Key("+reload", "R"))
	end

	if SERVER then

		self:SetUseType(SIMPLE_USE)

		net.Receive("controlPlayer", function(len, ply) demonicSheepFnc.receiveClientControlData(len, ply) end)

		self:NetworkVarNotify("allowDrop", function(entity, name, old, new) self.AllowDrop = new end)

		self:SetcurrentControlType(1)
	end

	-- Add a hook to be able to show your world model, when flying
	hook.Add("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer" .. tostring(self:GetmyId()), function()
		if not self.shouldDrawLocalPlayer then return end
		return self:shouldDrawLocalPlayer()
	end)

	-- Manage the dropped Item to give you the real SWEP and remove both
	hook.Add("PlayerUse", "demonicsheepPickupItem" .. tostring(self:GetmyId()), function(ply, entity)
		if IsValid(ply) and IsValid(entity) and entity:GetModel() == self.ItemModel
		and ply:CanCarryType(WEAPON_EQUIP2) and entity:GetNWInt("myId") and entity:GetNWInt("myId") == self:GetmyId() then
			ply:PickupWeapon(self)

			entity:Remove()
			return false
		end
		if IsValid(ply) and entity == self and IsEntity(self:GetitemDrop()) then self:GetitemDrop():Remove() end
		return
	end)

	if CLIENT then
		-- Add a Target ID to the Item using the actual weapon's infos
		hook.Add("TTTModifyTargetedEntity", "demonicSheepChangeItemInfos" .. tostring(self:GetmyId()), function(ent, distance)
			if ent:GetClass() ~= "prop_physics" or not ent:GetNWInt("myId") or ent:GetNWInt("myId") ~= self:GetmyId() then return end
			return self
		end)

		-- Disable the text of the dropped SWEP-Entity
		hook.Add("TTTRenderEntityInfo", "demonicSheepBlockOldItemInfos" .. tostring(self:GetmyId()), function(tData)
			local ent = tData:GetUnchangedEntity() or tData:GetEntity()
			if ent:GetClass() ~= "weapon_ttt_demonicsheep" or ent:GetmyId() ~= self:GetmyId() then return end
			tData:EnableText(false)
		end)
	end
end

function SWEP:SetNetworkedVariables()
	self:SetmyId(demonicSheepSwepCount)

	self:SetholsterToWep(self)
	self:SetallowHolster(true)
	self:SetallowDrop(true)
	self:SetlastAngleSet(false)
	self:SetlastAngle(Angle())
	self:SetdrawWorldModel(true)

	-- Set Networked Variables for demonicSheep Control
	for k,v in ipairs(player.GetAll()) do
		if v:GetNWBool("isDemonicSheepControlled", nil) then continue end
		v:SetNWBool("isDemonicSheepControlled", false)
		v:SetNWString("demonicSheepControlKey", "None")
		v:SetNWFloat("demonicSheepControlEndTime", CurTime())
	end
end

function SWEP:Equip(newOwner)
	print("Equip")
	self:SetlastOwner(newOwner)
end

function SWEP:Deploy()
	print("Deploy")
	-- Plays Draw_Weapon-Animation of the Sheep in your Hands
	local bPlayDrawAnimation = true
	self:playDrawWeaponAnimation(bPlayDrawAnimation)

	-- Allows general holstering
	if SERVER then
		self:SetallowHolster(true)
		self:SetholsterSheepAnimation(true)
		self:SetdrawWorldModel(not self:GetallowViewSwitching())
	end
	self.holsterSheepTimer = nil

	-- In case the weapon changed owner
	local demonicSheepEnt = self:GetdemonicSheepEnt()
	if IsValid(demonicSheepEnt) and demonicSheepEnt:GetOwner() ~= self:GetOwner() then
		demonicSheepEnt:SetOwner(self:GetOwner())
	end
end

function SWEP:Holster(wep)
	if not self:GetallowHolster() then return false end

	-- Animate the Sheep and send a timer before actually holstering it
	if not self.holsterSheepTimer and self:GetholsterSheepAnimation() then
		self:SendWeaponAnim(ACT_VM_HOLSTER)

		-- Set Timer and subtract 0.1 to holster before animation is finished
		self.holsterSheepTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration() - 0.1
		if SERVER then
			self:SetholsterToWep(wep)
		end
	end

	-- As long as the Animation is not done, don't allow holstering it
	if self:GetholsterSheepAnimation() and self.holsterSheepTimer then return false end

	-- To prevent Holstering again and creating a loop 
	if SERVER then
		self:SetholsterSheepAnimation(true)
		self:SetallowHolster(false)
		self:SetdemonicSheepEntInUse(false)
	end
	return true
end

function SWEP:OnDrop()
	if not self:GetallowDrop() then return false end
	if IsValid(self:GetdemonicSheepEnt()) then
		self:GetdemonicSheepEnt():SetOwner(nil)
	end

	if SERVER then
		self:SetdemonicSheepEntInUse(false)
		self:SetdrawWorldModel(false)
		self:dropItemModel()
	end
	print("Dropped")
	return
end

function SWEP:dropItemModel()
	ent_item = ents.Create("prop_physics")

	ent_item:SetModel(self.ItemModel)
	ent_item:SetPos(self:GetPos() + self:GetlastOwner():GetAimVector() * 10)
	ent_item:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ent_item:SetNWInt("myId", self:GetmyId())
	ent_item:SetUseType(SIMPLE_USE)
	self:SetitemDrop(ent_item)

	ent_item:Spawn()
	local phys = ent_item:GetPhysicsObject()
	phys:ApplyForceCenter(self:GetlastOwner():GetPhysicsObject():GetVelocity() * 2 + self:GetlastOwner():GetAimVector() * 400 + Vector(0, 0, 100))
	phys:AddAngleVelocity(self:GetlastOwner():GetAimVector() * 100)
end

function SWEP:OnRemove()
	self:RemoveHooks()

	-- Allow safe Removal
	if SERVER then
		self:SetdemonicSheepEntInUse(false)
		self:SetdemonicSheepEntOut(false)
		if IsEntity(self:GetitemDrop()) then self:GetitemDrop():Remove() end
	end

	if IsValid(self:GetdemonicSheepEnt()) and SERVER then
		self:GetdemonicSheepEnt():Remove()
		self:SetdemonicSheepEnt(nil)
	end

	print("Removed")
	return
end

function SWEP:PrimaryAttack()
	if self:GetdemonicSheepEntOut() then
		-- Control Sheep, don't launch it again and let this only be controlled by the Client
		-- As the Client could cheat, check the received Data of the Client
		if not self:GetdemonicSheepEntInUse() or SERVER then return end
		local ent = self:GetdemonicSheepEnt()

		if not IsValid(ent) or not self:GetdemonicSheepEntInUse() then return end

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

		local currentControl = self.availableControls[self:GetcurrentControlType()]
		tracedEnt:SetNWBool("isDemonicSheepControlled", true)
		tracedEnt:SetNWString("demonicSheepControlKey", currentControl[1])
		tracedEnt:SetNWFloat("demonicSheepControlEndTime", CurTime() + currentControl[2])

		-- Make sure that visually hit entities on the client are sent to the server
		if CLIENT then
			net.Start("controlPlayer")
			net.WriteInt(self:GetmyId(), 8)
			net.WriteEntity(tracedEnt)
			net.WriteInt(trace.PhysicsBone, 8)
			net.SendToServer()
		end
	else
		self:launchSheep()
	end
end

function SWEP:launchSheep()
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:EmitSound("demonicsheep_baa")
	self:SetdemonicSheepEntOut(true)
	self:SetallowDrop(false)
	self:SetallowHolster(false)

	-- Initialize entity after animation is finished
	self.initializeSheepTimer = CurTime() + self:GetOwner():GetViewModel():SequenceDuration()
	hook.Add("CreateMove", "blockPlayerActionsInLaunch"  .. tostring(self:GetmyId()), function(cmd)
		cmd:ClearMovement()
		cmd:ClearButtons()
	end)
	hook.Add("TTTModifyTargetedEntity", "demonicSheepTargetId" .. tostring(self:GetmyId()), function()
		if not self.remoteTargetId then return end
		return self:remoteTargetId()
	end)

	hook.Add("StartCommand", "readPlayerMovement" .. tostring(self:GetmyId()), function(ply, cmd)
		if not self.controlSheep then return end
		self:controlSheep(ply, cmd)
	end)

	hook.Add("StartCommand", "manipulatePlayerActions" .. tostring(self:GetmyId()), function(ply, cmd)
		if not self.manipulatePlayer then return end
		self:manipulatePlayer(ply, cmd)
	end)
	hook.Add("Move", "blockPlayerActions"  .. tostring(self:GetmyId()), function(ply, mv)
		if not self.blockPlayerActions then return end
		return self:blockPlayerActions(ply, mv)
	end)

	if SERVER then
		local ent = ents.Create("ent_demonicsheep")

		if (not IsValid(ent)) then return end

		local ply = self:GetOwner()
		self:SetdemonicSheepEnt(ent)

		ent:SetPos(ply:EyePos() + ply:EyeAngles():Forward() * 50)
		ent:SetAngles(ply:EyeAngles())
		ent:SetOwner(ply)
		ent.demonicSheepSwep = self

		ent:Spawn()
		ent:Activate()
	end
end

function SWEP:SecondaryAttack()
	self:SetNextSecondaryFire(CurTime() + 0.2)

	if not IsFirstTimePredicted() then return end
	print("Marker for Swep id " .. self:GetmyId() .. "/" .. demonicSheepSwepCount)
	if SERVER then
		self:SetcurrentControlType(1 + math.fmod(self:GetcurrentControlType(), #self.availableControls))
	end
end

function SWEP:Reload()
	if self.nextReload >= CurTime() then return end
	if not IsFirstTimePredicted() then return end
	if not self:GetallowViewSwitching() then return end
	self.nextReload = CurTime() + 0.3
	local reversedEntInUse = not self:GetdemonicSheepEntInUse()
	if SERVER then
		self:SetdemonicSheepEntInUse(reversedEntInUse)
		--self:SetallowHolster(not reversedEntInUse)
		--self:SetallowDrop(not reversedEntInUse)
	end


	if reversedEntInUse then
		self:SetHoldType("magic")
		if self:GetlastAngleSet() then
			self:SetlastAngleSet(false)
		end
	else
		self:SetHoldType("normal")
		-- Make sure, that the sheep doesn't fly away, when a key was pressed while switching Views
		self:GetdemonicSheepEnt():SetMoveDirection(Vector(0, 0, 0))
	end

end

function SWEP:Think()

	-- Switching to idle Animation after Draw Weapon Animation got played
	if not self:GetdemonicSheepEntOut() and not self:GetdemonicSheepEntInUse() and self.resetSightsTimer and self.resetSightsTimer <= CurTime() then
		self.resetSightsTimer = nil
		self:SendWeaponAnim(ACT_VM_IDLE)
		self.primaryAttDuration = self:GetViewModelSequenceDuration(ACT_VM_PRIMARYATTACK)
	end

	-- Allowing to holster after playing its Animation
	if self.holsterSheepTimer and self.holsterSheepTimer <= CurTime() then
		self.holsterSheepTimer = nil

		-- Use Input Commands for Prediction
		if CLIENT then
			input.SelectWeapon(self:GetholsterToWep())
		end

		-- Select Weapon on Server for other cases, i.e. switching to weapon with "use"-key
		if SERVER then
			self:GetOwner():SelectWeapon(WEPS.GetClass(self:GetholsterToWep()))
			self:SetholsterSheepAnimation(false)
		end
	end

	-- Initializing the demonic sheep before animation got fully played to have it available for Control
	if self.initializeSheepTimer and self.initializeSheepTimer <= CurTime() + 0.4 then
		self.enableControlSheepTimer = self.initializeSheepTimer
		self.initializeSheepTimer = nil
		if CLIENT then
			-- Bone number 45 is the Demonicsheep_Breast 
			local ent = self:GetdemonicSheepEnt()
			if not IsValid(ent) then return end

			--Set Position depending on the view model clientside
			local pos = self:GetOwner():GetViewModel():GetBoneMatrix(45):GetTranslation()
			ent:SetPos(pos)
			ent:SetAngles(self:GetOwner():EyeAngles())
		end
	end

	-- Shortly after Initialization actually show the sheep and enable Controls
	if self.enableControlSheepTimer and self.enableControlSheepTimer <= CurTime() + 0.2 and IsValid(self:GetdemonicSheepEnt()) then
		self.enableControlSheepTimer = nil

		if SERVER then
			self:SetdemonicSheepEntInUse(true)
			self:SetallowViewSwitching(true)
			self:SetallowDrop(true)
			self:SetallowHolster(true)
			self:SetdrawWorldModel(false)
			self:GetdemonicSheepEnt():EnableRendering(true)
			self:GetdemonicSheepEnt():EnablePhysicsControl(true, 1.7)
			self:SendWeaponAnim(ACT_VM_IDLE)
			self:SetHoldType("magic")
		end

		if CLIENT then
			hook.Remove("CreateMove", "blockPlayerActionsInLaunch" .. tostring(self:GetmyId()))
		end
	end

end

-- This controls if the viewModel should be drawn or not
function SWEP:ShouldDrawViewModel()
	return not self:GetallowViewSwitching()
end

-- This controls if the SWEP Model should be drawn or not
function SWEP:DrawWorldModel()
	if not self:GetdrawWorldModel() then return end
	self:DrawModel()
end

function SWEP:CalcView(ply, pos, ang, fov )
	if self:GetdemonicSheepEntInUse() then
		local ent = self:GetdemonicSheepEnt()
		if IsValid(ent) then
			pos, ang = self:demonicSheepView(ent)
		end
	end
	return pos, ang, fov
end

function SWEP:demonicSheepView(ent)
	local pos = ent:GetPos()
	local ang = ent:GetAngles()
	pos = pos - ang:Forward() * self.sheepViewDistanceForward + ang:Up() * self.sheepViewDistanceUp

	return pos,ang
end

-- To show Target IDs of players this is hooked to TTTModifyTargetedEntity and calculates the entity, the sheep can see
function SWEP:remoteTargetId()
	local ent = self:GetdemonicSheepEnt()
	if not IsValid(ent) or not self:GetdemonicSheepEntInUse() then return end

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
	if self:GetdemonicSheepEntInUse() and LocalPlayer() == self:GetOwner() then
		return true
	else
		-- Let other addons be able to decide if it should be shown by returning nothing
		return
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

		if not IsValid(wep) or wep ~= self or not self:GetdemonicSheepEntInUse() then return end
		local ent = self:GetdemonicSheepEnt()

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

		if not IsValid(wep) or wep ~= self or not self:GetdemonicSheepEntInUse() then return end

		if not self:GetlastAngleSet() then
			self:SetlastAngle(mv:GetAngles())
			self:SetlastAngleSet(true)
		end

		-- Set MoveDataVelocity to 0, this disables all other physics interactions
		mv:SetVelocity(Vector(0,0,0))
		ply:SetEyeAngles(self:GetlastAngle())

		-- Return true to block defaul Calculation of Movement-Data and stop Animations
		return true
	end
--

function SWEP:manipulatePlayer(ply, cmd)
	if not IsValid(ply) or not ply:GetNWBool("isDemonicSheepControlled") or not IsValid(self:GetOwner()) then return end
	local wep = self:GetOwner():GetActiveWeapon()

	if not IsValid(wep) or wep ~= self or not self:GetdemonicSheepEntInUse() then return end

	local endTime = ply:GetNWFloat("demonicSheepControlEndTime")
	if endTime  >= CurTime() then
		local controlKey = ply:GetNWString("demonicSheepControlKey")
		if controlKey == "None" then return end
		if controlKey == "Attack" then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
		elseif controlKey == "Drop Weapon" then
			if SERVER and #ply:GetWeapons() > 3 and ply:GetActiveWeapon().AllowDrop then
				ply:DropWeapon() -- only available on Server
			else
				ply:SetNWBool("isDemonicSheepControlled", false)
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
			ply:SetNWBool("isDemonicSheepControlled", false)
		elseif controlKey == "Move Forward" then
			cmd:SetButtons(cmd:GetButtons() + IN_FORWARD)
			cmd:SetForwardMove(cmd:GetForwardMove() + 9950)
		elseif controlKey == "Move Backward" then
			cmd:SetButtons(cmd:GetButtons() + IN_BACK)
			cmd:SetForwardMove(cmd:GetForwardMove() - 9950)
		end
	else
		ply:SetNWBool("isDemonicSheepControlled", false)
	end
end

function demonicSheepFnc.receiveClientControlData(len, ply)
	if len and len < 1 then
		print("ERROR: Empty Message received by " .. tostring(ply) .. " for PrimaryAttack Sheep Control in demonicSheepFnc.receiveClientControlData")
		return
	end
	local entityId = net.ReadInt(8)
	if not entityId or entityId > demonicSheepSwepCount or not IsValid(ply) then return end
	local swep = ply:GetActiveWeapon()
	if not IsValid(swep) or swep:GetClass() ~= "weapon_ttt_demonicsheep" then return end

	local tracedEnt = net.ReadEntity()
	if not IsValid(tracedEnt) or not tracedEnt:IsPlayer() then return end

	-- Make sure, the client didn't send a false entity which can't be controlled by the Sheep
	local physBone = net.ReadInt(8)
	local physBoneCount = tracedEnt:GetBoneCount()
	if physBone > physBoneCount then return end

	local bone = tracedEnt:TranslatePhysBoneToBone(physBone)
	local bonePos = tracedEnt:GetBonePosition(bone)

	local startPos = swep:demonicSheepView(swep:GetdemonicSheepEnt())
	local trace = util.TraceLine({
		start = startPos,
		endpos = bonePos,
		mask = MASK_SHOT,
		filter = {swep:GetdemonicSheepEnt()}
	})

	if not IsValid(trace.Entity) or trace.Entity ~= tracedEnt then return end
	swep:SetNextPrimaryFire(CurTime() + swep.Primary.Delay)

	-- Finally overwrite controls of the trace Entity
	local currentControl = swep.availableControls[swep:GetcurrentControlType()]
	tracedEnt:SetNWBool("isDemonicSheepControlled", true)
	tracedEnt:SetNWString("demonicSheepControlKey", currentControl[1])
	tracedEnt:SetNWFloat("demonicSheepControlEndTime", CurTime() + currentControl[2])

	-- Play the controlsound for all
	swep:EmitSound("demonicsheep_controlsound")
end

-- This is a Helper-Function to get the Sequence Duration of the Viewmodel with the input sequence ID
function SWEP:GetViewModelSequenceDuration(seqid)
	local vModel = self:GetOwner():GetViewModel()
	local seq = vModel:SelectWeightedSequence(seqid)
	return vModel:SequenceDuration(seq) or 0
end

function SWEP:RemoveHooks()

		if CLIENT then
			hook.Remove("CreateMove", "blockPlayerActionsInLaunch" .. tostring(self:GetmyId()))
		end
		hook.Remove("PlayerUse", "demonicsheepPickupItem" .. tostring(self:GetmyId()))
		hook.Remove("Move", "blockPlayerActions" .. tostring(self:GetmyId()))
		hook.Remove("ShouldDrawLocalPlayer", "demonicsheepShowLocalPlayer" .. tostring(self:GetmyId()))
		hook.Remove("TTTModifyTargetedEntity", "demonicSheepTargetId" .. tostring(self:GetmyId()))
		hook.Remove("TTTModifyTargetedEntity", "demonicSheepChangeItemInfos" .. tostring(self:GetmyId()))
		hook.Remove("TTTRenderEntityInfo", "demonicSheepBlockOldItemInfos" .. tostring(self:GetmyId()))
		hook.Remove("StartCommand", "readPlayerMovement" .. tostring(self:GetmyId()))
		hook.Remove("StartCommand", "manipulatePlayerActions" .. tostring(self:GetmyId()))
end

-- OLD Code that could be helpful to get some stuff done
--[[
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
--]]