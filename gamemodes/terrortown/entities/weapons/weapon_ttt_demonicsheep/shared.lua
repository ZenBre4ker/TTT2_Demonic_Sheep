if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("InitializedDemonicSheep")
end

local DemonicSheepSwep
local Demonicsheep_out = false
--SWEP.Demonicsheep_out	= false
local skipAnimationConV = GetConVar("ttt_DemnShp_SkipAnimation")
local demnShpDurationConV = GetConVar("ttt_DemnShp_duration")

SWEP.Base				= "weapon_tttbase"

SWEP.PrintName			= "Demonic Sheep"			  
SWEP.Author				= "ZenBreaker"  
SWEP.Instructions		= "Launch the Demonic Sheep, aim at your enemies and control them to drive them mad!"
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
--SWEP.Primary.Recoil	= 8
--SWEP.Primary.Damage	= 24
--SWEP.Primary.Delay	= 0.8
SWEP.Primary.Cone		= 0
SWEP.Primary.ClipSize	= 1
SWEP.Primary.ClipMax	= 1
SWEP.Primary.DefaultClip= 1
SWEP.Primary.Automatic	= false

SWEP.Secondary.Automatic= false
SWEP.Secondary.Delay	= 5

SWEP.ViewModelFlip  	= false
SWEP.DrawCrosshair 		= false
SWEP.UseHands			= true
SWEP.ViewModelFOV		= 60
SWEP.ViewModel			= "models/weapons/v_ttt_demonicsheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_demonicsheep.mdl"
SWEP.IronSightsPos		= Vector(2.773, 0, 0.846)
SWEP.IronSightsAng		= Vector(-0.157, 0, 0)






if ConVarExists("ttt_vote") then
	hook.Add("HUDDrawTargetID", "demonicsheep_TargetID", hudtargetidimpl_totem)
elseif TTT2 then
	hook.Add("HUDDrawTargetID", "demonicsheep_TargetID", hudtargetidimpl_ttt2)
else
	hook.Add("HUDDrawTargetID", "demonicsheep_TargetID", hudtargetidimpl_default)
end

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
			if(not IsValid(ply) or ply:GetNWBool("Spectatedemonicsheep") ~= true or not IsValid(ply:GetNWEntity("Spectating_demonicsheep"))) then return end
			local demonicsheep_ent = ply:GetNWEntity("Spectating_demonicsheep")
			local view = {}
			local minifiedViewOrigin = demonicsheep_ent:GetPos() -( angles:Forward()*50 + Vector(0, 0, -10))
			local magnifiedViewOrigin = demonicsheep_ent:GetPos() -( angles:Forward()*100 + Vector(0, 0, -45))
			local interpolValue = 1
			if demonicsheep_ent.MinifiedStart then
				interpolValue = CurTime() - demonicsheep_ent.MinifiedStart
			end
		
			if demonicsheep_ent.Minified then		
				if(interpolValue < 1) then
					view.origin = minifiedViewOrigin * interpolValue + magnifiedViewOrigin * (1- interpolValue)
				else
					view.origin = minifiedViewOrigin
				end
			else
				if(interpolValue < 1) then
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
			if(observerTarget ~= nil and IsValid(observerTarget) and observerTarget:IsPlayer() and observerTarget:Alive() and IsValid(observerTarget:GetActiveWeapon()) and observerTarget:GetActiveWeapon():GetClass() == "weapon_ttt_demonicsheep") then
				local demonicsheep_entity = observerTarget:GetNWEntity("demonicsheep_entity")
				if(IsValid(demonicsheep_entity) and SERVER) then
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
	local minifiedViewOrigin = slf.Ent_demonicsheep:GetPos() - (ang:Forward()*50 + Vector(0, 0, -10))
	local magnifiedViewOrigin = slf.Ent_demonicsheep:GetPos() - (ang:Forward()*100 + Vector(0, 0, -45))
	local interpolValue = CurTime() - slf.Ent_demonicsheep.MinifiedStart
	local isMinified = slf.Ent_demonicsheep.Minified

	if isMinified then		
		if(interpolValue < 1) then
			pos = minifiedViewOrigin * interpolValue + magnifiedViewOrigin * (1- interpolValue)
		else
			pos = minifiedViewOrigin
		end
	else
		if(interpolValue < 1) then
			pos = magnifiedViewOrigin * interpolValue + minifiedViewOrigin * (1- interpolValue)
		else
			pos = magnifiedViewOrigin
		end
	end
	return pos, ang
end

function SWEP:Holster()
	if not IsValid(self.LastOwner) then return false end
	return (not self.DontHolster or self.LastOwner:GetNWBool("demonicsheep_removed"))
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
	timer.Destroy("demonicsheepBoost" .. tostring(self))
end

local function ShadowedText(text, font, x, y, color, xalign, yalign)

   draw.SimpleText(text, font, x+2, y+2, COLOR_BLACK, xalign, yalign)
 
   draw.SimpleText(text, font, x, y, color, xalign, yalign)
end

if not TTT2 then

	function SWEP:DrawHUD()
		if IsValid(self.Ent_demonicsheep) and self.SheepStartTime >= 0 then
			local y = ScrH() - 150 - 15
			draw.RoundedBox(8, ScrW() / 2 - 170, y, 340, 150, Color(0, 0, 10, 200))
			
			--draw boost
			draw.RoundedBox( 8, ScrW() / 2 - 151, y + 59, 302, 27 , Color(20, 20, 5, 222) )
			draw.RoundedBox( 8, ScrW() / 2 - 150, y + 60, (self.Boost / self.MaxBoost) * 300, 25 , Color(205, 155, 0, 255) )

			ShadowedText("R - Boost", "HealthAmmo", ScrW() / 2, y + 60 + 12, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			--draw last size change
			local sizeChangeBar = math.min(CurTime() - self.LastSizeChange, 5) / 5.0
			
			draw.RoundedBox( 8, ScrW() / 2 - 151, y + 109, 302, 27 , Color(20, 20, 5, 222) )
			draw.RoundedBox( 8, ScrW() / 2 - 150, y + 110, sizeChangeBar * 300, 25 , Color(205, 155, 0, 255) )
			
			if self.Minified then
				ShadowedText("Right Click - Magnify", "HealthAmmo", ScrW() / 2, y + 110 + 12, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				ShadowedText("Right Click - Minify", "HealthAmmo", ScrW() / 2, y + 110 + 12, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			
			-- draw time left
			self.TimeLeft = math.Truncate(30 - (CurTime() - self.SheepStartTime),0) + 1
			--if self.TimeLeft > 10 or self.TimeLeft <= -1 then return end
			if 30 - (CurTime() - self.SheepStartTime) < 0 then self.TimeLeft = 0 end 
			
			draw.RoundedBox(12, ScrW() / 2 - 21, y + 9, 42, 42 , Color(20, 20, 5, 222) ) 
			draw.RoundedBox(12, ScrW() / 2 - 20, y + 10, 40, 40 , Color(200, 46, 46, 255) ) 
			ShadowedText(tostring(self.TimeLeft), "HealthAmmo", ScrW() / 2, y + 30, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			return self.BaseClass.DrawHUD(self)
		end
		
	end
end