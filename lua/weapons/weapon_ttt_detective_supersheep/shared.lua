if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("targetid_implementations/shared.lua")
	util.AddNetworkString("TTTSSRESET")
end

include( "targetid_implementations/shared.lua" )

SWEP.HoldType			= "knife"

SWEP.PrintName			= "Observer Sheep"			  
SWEP.Author				= "TheBroomer"  
SWEP.Instructions			= "Launch the Observer Sheep to track your enemies!"
SWEP.Slot				= 1
SWEP.SlotPos			= 2
SWEP.Icon = "vgui/ttt/supersheep/observersheep.png"

SWEP.Base				= "weapon_tttbase"

SWEP.Spawnable = false
SWEP.Kind = WEAPON_EQUIP2
SWEP.AutoSpawnable = false
SWEP.CanBuy = { ROLE_TRAITOR, ROLE_DETECTIVE }
SWEP.LimitedStock = false

SWEP.DeploySpeed = 0.01
SWEP.Primary.Ammo       = "Observer Sheep" 
--SWEP.Primary.Recoil			= 8
--SWEP.Primary.Damage = 24
--SWEP.Primary.Delay = 1
SWEP.Primary.Cone = 0
SWEP.Primary.ClipSize = 100
SWEP.Primary.ClipMax = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = false

SWEP.Secondary.Automatic = true

SWEP.AutoSpawnable      = false

SWEP.ViewModelFlip  	= false
SWEP.DrawCrosshair 		= false
SWEP.UseHands			= true
SWEP.ViewModelFOV		= 60
SWEP.ViewModel			= "models/weapons/v_ttt_detective_supersheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_detective_supersheep.mdl"
SWEP.IronSightsPos = Vector(2.773, 0, 0.846)
SWEP.IronSightsAng = Vector(-0.157, 0, 0)

--SWEP.HUDShouldDraw = false



SWEP.EquipMenuData = {
	type = "item_weapon",
	desc = [[
	Launch the Observer Sheep to track your enemies!
	Left-Click: Mark a person
	Right-Click: Get the sheep back
	]]
}
SWEP.supersheep_out = false
SWEP.FirstCall = false

if CLIENT then
	net.Receive("TTTSSRESET", function()
		local wep = net.ReadEntity()
		wep:ResetSheep()
	end)
	
	if ConVarExists("ttt_vote") then
		hook.Add("HUDDrawTargetID", "Supersheep_Detective_TargetID", hudtargetidimpl_totem)
	elseif TTT2 then
		hook.Add("HUDDrawTargetID", "Supersheep_Detective_TargetID", hudtargetidimpl_ttt2)
	else
		hook.Add("HUDDrawTargetID", "Supersheep_Detective_TargetID", hudtargetidimpl_default)
	end

end

local function ShadowedText(text, font, x, y, color, xalign, yalign)

   draw.SimpleText(text, font, x+2, y+2, COLOR_BLACK, xalign, yalign)
 
   draw.SimpleText(text, font, x, y, color, xalign, yalign)
end

hook.Add("PreDrawHalos","SupersheepTracker", function()
	local tbl = {}
	if LocalPlayer().trackedSSPlayers != nil then
		for i = 1,table.Count(LocalPlayer().trackedSSPlayers) do 
			local tracked = LocalPlayer().trackedSSPlayers[i]
			local startTime = LocalPlayer().trackedSSStarttimes[i]
			
			if IsValid(tracked) && !tracked:GetNoDraw() && startTime + 30 > CurTime() then
				table.insert(tbl, tracked)
			end
		end
		
		halo.Add(tbl,Color(0,255,0),2,2,2,true,true)
	end
end)

hook.Add("TTTPrepareRound", "RemoveSupersheepTrackers", function()
	for k, v in ipairs(player.GetAll()) do
		
		v.trackedSSPlayers = {}
		v.trackedSSStarttimes = {}
	end
end)

hook.Add("SetupPlayerVisibility", "Supersheep_Detective_AddToPVS", function(ply, viewent)
	if IsValid(ply) && IsValid(ply:GetNWEntity("supersheep_entity")) then
		local sheep = ply:GetNWEntity("supersheep_entity")
		AddOriginToPVS( sheep:GetPos() )
	end
end)

hook.Add("PlayerUse", "Supersheep_Detective_PickupItem", function(ply, entity)
		if IsValid(ply) && IsValid(entity) && entity:GetModel() == "models/weapons/item_ttt_detective_supersheep.mdl" && ply:CanCarryType(WEAPON_EQUIP2) then
			ply:Give("weapon_ttt_detective_supersheep")
			
			local wep = ply:GetWeapon("weapon_ttt_detective_supersheep")
			if IsValid(wep) then
				wep:SetClip1(entity.Clip1)
			end
			
			entity:Remove()
			return false
		end
end)

function SWEP:Initialize()
	self:SetWeaponHoldType("knife")
	self.DontHolster = false
	self.Ent_supersheep = nil
	self.supersheep_out = false
	self.FirstCall = false
	self.AnimationFinished = true
	self.CanFly = false
	self.IsFlying = false
	self.CancelSound = false
	
	self.isBoosting = false
	self.BoostPressed = false
	self.Boost = 100
	self.MaxBoost = 100
	
	self.SheepStartTime = -1
	self.LastTrack = 0
	
	timer.Create("SupersheepBoost_Detective" .. tostring(self), 0.05, 0, function()
		if IsValid(self.Ent_supersheep) && self.SheepStartTime >= 0 then
			if self.isBoosting then
				self.Boost = math.max(self.Boost - 2, 0)		
			else
				self.Boost = math.min(self.Boost + 1, self.MaxBoost) 
			end
		end
	end)

	sound.Add( {
	name = "supersheep_wind",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	sound = "ambient/levels/canals/windmill_wind_loop1.wav"
} )

local function Supersheep_ObserverView( ply, pos, angles, fov )
		if(not IsValid(ply) || ply:GetNWBool("SpectateSupersheep_Detective") != true || not IsValid(ply:GetNWEntity("Spectating_Supersheep_Detective"))) then return end
		local supersheep_ent = ply:GetNWEntity("Spectating_Supersheep_Detective")
		local view = {}
		view.origin = supersheep_ent:GetPos() -( angles:Forward()*50 + Vector(0, 0, -10))
		view.angles = angles
		view.fov = fov
		view.drawviewer = true

		return view
end

hook.Add( "CalcView", "Supersheep_Detective_ObserverView", Supersheep_ObserverView )

hook.Add("Think", "Supersheep_Detective_LetPlayerObserve", function()
for k, v in pairs( player.GetAll() ) do
	local observerTarget = v:GetObserverTarget()
	if(observerTarget != nil && IsValid(observerTarget) && observerTarget:IsPlayer() && observerTarget:Alive() && IsValid(observerTarget:GetActiveWeapon()) && observerTarget:GetActiveWeapon():GetClass() == "weapon_ttt_detective_supersheep") then
		local supersheep_entity = observerTarget:GetNWEntity("supersheep_entity")
		if(IsValid(supersheep_entity) && SERVER) then
			--v:SpectateEntity(supersheep_entity)
			--v:Spectate(OBS_MODE_CHASE)
			v:SetNWBool("SpectateSupersheep_Detective",true)
			v:SetNWEntity("Spectating_Supersheep_Detective", supersheep_entity)
		else
			--v:SetNWBool("SpectateSupersheep",false)
		end
	else
		v:SetNWBool("SpectateSupersheep_Detective",false)
	end
end
end)


		if CLIENT then
		surface.CreateFont("Supersheep_Font",   {font = "Trebuchet24",
                                    size = 18,
                                    weight = 750})
		end
		
		if CLIENT then
		surface.CreateFont("Small_Supersheep_Font",   {font = "ChatFont",
                                    size = 12,
                                    weight = 750})
		end

end

function SWEP:PrimaryAttack(worldsnd)
	
	if(!self.AnimationFinished) then return end
	
	if not self.supersheep_out then
		local function Supersheep_PreventDucking( cmd )
			if not IsValid(self) || not IsValid(self.Owner) || self.FirstCall then return end
			cmd:RemoveKey(IN_DUCK)
		end
		hook.Add( "CreateMove", "Supersheep_Detective_PreventDucking", Supersheep_PreventDucking )
		
		self.CancelSound = false
		self.AllowDrop = false
		
		self:EmitSound("ttt_supersheep/sheep_sound.wav")
		self.AnimationFinished = false
		
		-- self.Owner:GetViewModel():SetPlaybackRate( 1.0 )
		-- self:SetPlaybackRate( 1.0 )
		local VModel = self.Owner:GetViewModel()
		local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_PRIMARYATTACK )
		self.AnimationDuration = VModel:SequenceDuration(EnumToSeq)
		self.AnimationStartTime = CurTime()
		VModel:SendViewModelMatchingSequence( EnumToSeq )
		
		--self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

		-- self.Owner:SetNWBool("supersheep_exploded", false)
		
		-- self.supersheep_out = true
		-- self.FirstCall = false
		
		-- // The rest is only done on the server
		-- if (!SERVER) then return end
		
		-- self.Ent_supersheep = place( self:GetOwner())
	else
		if self.supersheep_out && CLIENT && IsValid(self.Ent_supersheep) then
			self.LastTrack = CurTime()
			
			local tr = util.TraceLine( {
			start = self.Ent_supersheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*50 + Vector(0, 0, -10)),
			endpos = self.Ent_supersheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -10)),
			mask = MASK_SHOT,
			filter = LocalPlayer():GetObserverMode() == OBS_MODE_IN_EYE and {LocalPlayer(), LocalPlayer():GetObserverTarget()} or LocalPlayer()
			} )
			if IsValid(tr.Entity) && tr.Entity:IsPlayer() && tr.Entity != LocalPlayer() then
				chat.PlaySound()
				if(LocalPlayer().trackedSSPlayers == nil or LocalPlayer().trackedSSStarttimes == nil) then
					LocalPlayer().trackedSSPlayers = {}
					LocalPlayer().trackedSSStarttimes = {}
				end
				table.insert(LocalPlayer().trackedSSPlayers, tr.Entity)
				table.insert(LocalPlayer().trackedSSStarttimes, CurTime())
				timer.Simple(30, function() chat.AddText(
							Color(200, 20, 20),
							"[Observer Sheep] ",
							Color(250, 250, 250),
							"You are no longer tracking ",
							Color(20, 250, 20),
							tr.Entity:Nick(), 
							".")
							chat.PlaySound()
				end)	
			end
		end
	end
	self:SetNextPrimaryFire(CurTime() + 1)
end

function SWEP:SecondaryAttack(worldsnd)
	if(!self.AnimationFinished) then return end
	
	if self.supersheep_out then
		self.Ent_supersheep:RemoveFromWorld()
		self:ResetSheep()
	end
end

function SWEP:Reload()
	if not IsValid(self) || not IsValid(self.Ent_supersheep) || not IsValid(self.Owner) then return end
	
	if self.Boost > 33 || (self.Boost > 0 && self.isBoosting )  then
		self.Ent_supersheep.Boost = true
		self.BoostPressed = true
	end
end

function SWEP:ResetSheep()
	if not IsValid(self.Ent_supersheep) then return end
	
	self.CancelSound = true
	self.FirstCall = false
	--self.Owner:SetNWBool("supersheep_removed", false)

	self.Owner:DrawViewModel(true)
	self:SetNoDraw(false)
	
	self.supersheep_out = false
	--self:StopSound("supersheep_wind")
	self.AllowDrop = true
	self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
end

function SWEP:Think()

if not self.isBoosting && self.BoostPressed then
	self.isBoosting = true
	self.Ent_supersheep:EmitSound("ttt_supersheep/sheep_sound.wav")
	if SERVER then
		local startWidth = 0.8
		local endWidth = 0
		if IsValid(self.Ent_supersheep) then
			self.TrailLeft = util.SpriteTrail( self.Ent_supersheep.TrailLeft, 0, Color(255,255,255), false, startWidth, endWidth, 0.07, 1 / ( startWidth + endWidth ) * 0.5, "trails/smoke.vmt" )
			self.TrailRight = util.SpriteTrail( self.Ent_supersheep.TrailRight, 0, Color(255,255,255), false, startWidth, endWidth, 0.07, 1 / ( startWidth + endWidth ) * 0.5, "trails/smoke.vmt" )
			self.Ent_supersheep:SetPlaybackRate(1.6)
		end
	end
elseif not self.BoostPressed then
	self.isBoosting = false
	if IsValid(self.TrailLeft) then self.TrailLeft:Remove() end
	if IsValid(self.TrailRight) then self.TrailRight:Remove() end
	if IsValid(self.Ent_supersheep) then self.Ent_supersheep:SetPlaybackRate(1.0) end
end	
self.BoostPressed = false

local VModel = self.Owner:GetViewModel()
local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_IDLE )

--VModel:SetSequence( EnumToSeq )

--self.Owner:GetViewModel():SetPlaybackRate(0.5)
--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
if not self.AnimationFinished && CurTime() > self.AnimationStartTime + self.AnimationDuration * 0.5 then
		self.AnimationFinished = true
		self.Owner:SetNWBool("supersheep_removed", false)
		self.Owner:SetNWBool("supersheep_small", true)
		self.Owner:DrawViewModel(false)
		self:SetNoDraw(true)
		self.supersheep_out = true
		self.FirstCall = false
		
		--The rest is only done on the server
		if SERVER then
		
			self.Ent_supersheep = self:PlaceSupersheep( self:GetOwner())
			
			hook.Add( "SetupPlayerVisibility", "Supersheep_Detective_AddRTCamera", function( pPlayer, pViewEntity )
				-- Adds any view entity
				if ( pViewEntity:IsValid() ) then
					AddOriginToPVS( pViewEntity:GetPos() )
				end
			end )
		
		end
		
		--timer.Create( "supersheep_running_timer", 0.5, 1, function() self.CanFly = true end )
		
		return
end

local function Supersheep_View( ply, pos, angles, fov )
		if not IsValid(self) || not IsValid(self.Ent_supersheep) || not IsValid(self.Owner) || ply != self.Owner || LocalPlayer():GetNWBool("supersheep_removed") then return end
		if not self.CancelSound then self:EmitSound("supersheep_wind") end
		
		local view = {}
		view.origin = self.Ent_supersheep:GetPos() -( angles:Forward()*50 + Vector(0, 0, -10))
		view.angles = angles
		view.fov = fov
		view.drawviewer = true

		return view
end

local function Supersheep_PreventMovement( cmd )
		if not IsValid(self.Ent_supersheep) || not IsValid(self) || not IsValid(self.Owner) || self.Owner:GetNWBool("supersheep_removed") then return end
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_USE)
end

self.Ent_supersheep = self.Owner:GetNWEntity("supersheep_entity")
if IsValid(self.Owner) and IsValid(self.Ent_supersheep) then
	self.Owner.supersheep = self
end

self.Ent_supersheep.Owner = self.Owner
self.Ent_supersheep.CorrespondingWeapon = self

if not self.FirstCall && IsValid(self.Ent_supersheep) then
	self.DontHolster = true
	self.SheepStartTime = CurTime()
	if CLIENT then
		timer.Create( "supersheep_detective_view_delay", 0.15, 1, function() hook.Add( "CalcView", "Supersheep_Detective_View", Supersheep_View ) 
		end)
	end
	hook.Add( "CreateMove", "Supersheep_Detective_PreventMovement", Supersheep_PreventMovement )
	self.FirstCall = true
end	

end


function SWEP:PlaceSupersheep( ply)
	
	if ( CLIENT ) then return end
	
		clearedEyeTrace = Vector(ply:GetEyeTrace().Normal.x, ply:GetEyeTrace().Normal.y, 0)
	
	-- local supersheep_nextBot = ents.Create("ent_supersheep_fakeplayer")
	-- supersheep_nextBot:Spawn()
	-- supersheep_nextBot:SetPos(ply:EyePos() + clearedEyeTrace * 200)
	
	local ent = ents.Create( "ent_detective_supersheep" )
	
	if ( !IsValid( ent ) ) then return end
	
	clearedEyeTrace = Vector(ply:GetEyeTrace().Normal.x, ply:GetEyeTrace().Normal.y, 0)
	perpEyeTrace = Vector(-clearedEyeTrace.y, clearedEyeTrace.x, 0)
	eyeAngles = ply:EyeAngles()
	
	local duckOffset = Vector(0, 0, 0)
	if ply:Crouching() then duckOffset = ply:GetViewOffsetDucked() end
	
	ent:SetPos( ply:EyePos() + clearedEyeTrace * 80 + Vector(0, 0, -30) + perpEyeTrace * -10 + duckOffset)
	ent:SetAngles(Angle(0, eyeAngles.y, 0))
	
	ent.Owner = ply
	ent.CorrespondingWeapon = self
	ent:Spawn()
	ent:Activate()
	
	ply:SetNWEntity("supersheep_entity", ent)
	
	local phys = ent:GetPhysicsObject()
	if ( !IsValid( phys ) ) then ent:Remove() return end
	
	return ent
	
end

function SWEP:Holster()
	if !IsValid(self.LastOwner) then return false end
	return (not self.DontHolster || self.LastOwner:GetNWBool("supersheep_removed"))
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
	--self.WorldModel = "models/weapons/item_ttt_supersheep.mdl"
	--self:SetModel("models/weapons/item_ttt_supersheep.mdl")
	
	if CLIENT then return end
	
	ent_item = ents.Create("prop_physics")
	
	ent_item:SetModel("models/weapons/item_ttt_detective_supersheep.mdl")
	ent_item:SetPos(self:GetPos() + self.LastOwner:GetAimVector() * 10)
	ent_item:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ent_item.Clip1 = self:Clip1()
	
	ent_item:Spawn()
	local phys = ent_item:GetPhysicsObject()
	phys:ApplyForceCenter(self.LastOwner:GetPhysicsObject():GetVelocity() * 2 + self.LastOwner:GetAimVector() * 400 + Vector(0, 0, 100))
	phys:AddAngleVelocity(self.LastOwner:GetAimVector() * 100)
	self:Remove()
end

function SWEP:OnRemove()
	--hook.Remove("PlayerUse", "Supersheep_PickupItem")
	--hook.Remove("CreateMove", "Supersheep_PreventMovement")
	--hook.Remove("CalcView", "Supersheep_View")
	self.CancelSound = true
	self:StopSound("supersheep_wind")
	if not IsValid(self.Owner) then return end
	local newWeapon = self.Owner:GetWeapons()[2]
	if (SERVER && IsValid(newWeapon)) then
		self.Owner:SelectWeapon(newWeapon:GetClass())
	end
	timer.Destroy("SupersheepBoost_Detective" .. tostring(self))
end

if not TTT2 then
	function SWEP:DrawHUD()
		if IsValid(self.Ent_supersheep) && self.SheepStartTime >= 0 then
			local y = ScrH() - 100 - 15
			draw.RoundedBox(8, ScrW() / 2 - 170, y, 340, 100, Color(0, 0, 10, 200))
			
			--draw last size change
			local trackBar = math.min(CurTime() - self.LastTrack, 1) / 1.0
			
			draw.RoundedBox( 8, ScrW() / 2 - 151, y + 9, 302, 27 , Color(20, 20, 5, 222) )
			draw.RoundedBox( 8, ScrW() / 2 - 150, y + 10, trackBar * 300, 25 , Color(205, 155, 0, 255) )

			ShadowedText("Left Click - Track", "HealthAmmo", ScrW() / 2, y + 10 + 12, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			--draw boost
			draw.RoundedBox( 8, ScrW() / 2 - 151, y + 59, 302, 27 , Color(20, 20, 5, 222) )
			draw.RoundedBox( 8, ScrW() / 2 - 150, y + 60, (self.Boost / self.MaxBoost) * 300, 25 , Color(205, 155, 0, 255) )

			ShadowedText("R - Boost", "HealthAmmo", ScrW() / 2, y + 60 + 12, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			return self.BaseClass.DrawHUD(self)
		end
		
	end
end