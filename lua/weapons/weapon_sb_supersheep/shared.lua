if SERVER then
	AddCSLuaFile()
end

if CLIENT then
    SWEP.PrintName = "Supersheep"
    SWEP.Author		= "TheBroomer"  
    --SWEP.Contact = "n/a"
    SWEP.Purpose = "Controllable explodable Supersheep (Worms 3D)"
	SWEP.Instructions			= "Launch the Supersheep, drive it to your enemies and blow them up!"
	SWEP.Slot				= 1
	SWEP.SlotPos			= 2
	SWEP.Category = "Worms3D Weapons"
    SWEP.WepSelectIcon = surface.GetTextureID("VGUI/icon_supersheep")
    SWEP.BounceWeaponIcon = true
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false
    --SWEP.Category = "Other"
end

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.HoldType			= "knife"
		  
--SWEP.Icon = "vgui/ttt/supersheep/supersheep.png"

--SWEP.Kind = WEAPON_EQUIP2
--SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = true

SWEP.DeploySpeed = 0.01
--SWEP.Primary.Ammo       = "Supersheep" 
--SWEP.Primary.Recoil			= 8
--SWEP.Primary.Damage = 24
--SWEP.Primary.Delay = 0.8
SWEP.Primary.Cone = 0
SWEP.Primary.ClipSize = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false

SWEP.AutoSpawnable      = false

SWEP.ViewModelFlip  	= false
SWEP.UseHands			= true
SWEP.ViewModelFOV		= 60
SWEP.ViewModel			= "models/weapons/v_ttt_supersheep.mdl"
SWEP.WorldModel			= "models/weapons/w_ttt_supersheep.mdl"
SWEP.IronSightsPos = Vector(2.773, 0, 0.846)
SWEP.IronSightsAng = Vector(-0.157, 0, 0)

-- SWEP.EquipMenuData = {
	-- type = "item_weapon",
	-- desc = [[
	
	-- Launch the Supersheep, drive it to your enemies 
	-- and blow them up!
	
	-- ]]
-- }
SWEP.Ent_supersheep = 0
SWEP.supersheep_out = false
SWEP.FirstCall = false


function SWEP:Initialize()
	--print("test123")
	self:SetWeaponHoldType("knife")
	self.DontHolster = false
	self.Ent_supersheep = 0
	self.supersheep_out = false
	self.FirstCall = false
	self.AnimationFinished = true
	self.CanFly = false
	self.IsFlying = false
	self.CancelSound = false
	self.SheepStartTime = -1
	self.LastBoostTime = 0
	
	sound.Add( {
	name = "supersheep_wind",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 75,
	sound = "ambient/levels/canals/windmill_wind_loop1.wav"
} )

		if CLIENT then
		surface.CreateFont("Supersheep_Font",   {font = "Trebuchet24",
                                    size = 18,
                                    weight = 750})
		end
end

function SWEP:PrimaryAttack(worldsnd)

	if not self.supersheep_out then
		local function Supersheep_PreventDucking( cmd )
			if not IsValid(self) || not IsValid(self.Owner) || self.FirstCall then return end
			cmd:RemoveKey(IN_DUCK)
		end
		hook.Add( "CreateMove", "Supersheep_PreventDucking", Supersheep_PreventDucking )
	
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
		-- if not self.CanFly && not self.IsFlying then return end
		-- if self.CanFly then
			-- self.IsFlying = true
			-- self.CanFly = false
			-- self:SetNextPrimaryFire(1)
			-- return
		-- end
		if not IsValid(self.Ent_supersheep) then return end
		self.Ent_supersheep:Explode()
	end
end

function SWEP:SecondaryAttack(worldsnd)
	if not IsValid(self) || not IsValid(self.Ent_supersheep) || not IsValid(self.Owner) || self.LastBoostTime + 5.0 >= CurTime() then return end
	self.LastBoostTime = CurTime()
	self.Ent_supersheep.Boost = true
end

function SWEP:Think()
local VModel = self.Owner:GetViewModel()
local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_IDLE )

--VModel:SetSequence( EnumToSeq )

--self.Owner:GetViewModel():SetPlaybackRate(0.5)
--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
--print(self.AnimationFinished)

if not self.AnimationFinished && CurTime() > self.AnimationStartTime + self.AnimationDuration * 0.5 then
		self.AnimationFinished = true
		self.Owner:SetNWBool("supersheep_exploded", false)
		self.Owner:DrawViewModel(false)
		self:SetNoDraw(true)
		self.supersheep_out = true
		self.FirstCall = false
		
		--The rest is only done on the server
		if SERVER then
		
			self.Ent_supersheep = place_supersheep( self:GetOwner())
		
		end
		
		--timer.Create( "supersheep_running_timer", 0.5, 1, function() self.CanFly = true end )
		
		return
end

local function Supersheep_View( ply, pos, angles, fov )
		if not IsValid(self) || not IsValid(self.Ent_supersheep) || not IsValid(self.Owner) || ply != self.Owner || LocalPlayer():GetNWBool("supersheep_exploded") then return end
		if not self.CancelSound then self:EmitSound("supersheep_wind") end
		local view = {}
		view.origin = self.Ent_supersheep:GetPos() -( angles:Forward()*100 + Vector(0, 0, -45))
		view.angles = angles
		view.fov = fov
		view.drawviewer = true

		return view
end

local function Supersheep_PreventMovement( cmd )
		if not IsValid(self.Ent_supersheep) || not IsValid(self) || not IsValid(self.Owner) || self.Owner:GetNWBool("supersheep_exploded") then return end
		cmd:ClearMovement()
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_USE)
end

self.Ent_supersheep = self.Owner:GetNWEntity("supersheep_entity")
self.Ent_supersheep.Owner = self.Owner
self.Ent_supersheep.CorrespondingWeapon = self

if not self.FirstCall && IsValid(self.Ent_supersheep) then
	self.SheepStartTime = CurTime()
	self.DontHolster = true
	if CLIENT then
		timer.Create( "supersheep_view_delay", 0.15, 1, function() hook.Add( "CalcView", "Supersheep_View", Supersheep_View ) end)
	end
	hook.Add( "CreateMove", "Supersheep_PreventMovement", Supersheep_PreventMovement )
	self.FirstCall = true
end	
if self.SheepStartTime >= 0 && 30 - (CurTime() - self.SheepStartTime) < -0.2 then
	self.Ent_supersheep:Explode()
end

end



function place_supersheep( ply)
	
	if ( CLIENT ) then return end
	
		clearedEyeTrace = Vector(ply:GetEyeTrace().Normal.x, ply:GetEyeTrace().Normal.y, 0)
	
	-- local supersheep_nextBot = ents.Create("ent_supersheep_fakeplayer")
	-- supersheep_nextBot:Spawn()
	-- supersheep_nextBot:SetPos(ply:EyePos() + clearedEyeTrace * 200)
	
	local ent = ents.Create( "ent_supersheep" )

	if ( !IsValid( ent ) ) then return end
	
	clearedEyeTrace = Vector(ply:GetEyeTrace().Normal.x, ply:GetEyeTrace().Normal.y, 0)
	perpEyeTrace = Vector(-clearedEyeTrace.y, clearedEyeTrace.x, 0)
	eyeAngles = ply:EyeAngles()
	
	local duckOffset = Vector(0, 0, 0)
	if ply:Crouching() then duckOffset = ply:GetViewOffsetDucked() end
	
	ent:SetPos( ply:EyePos() + clearedEyeTrace * 80 + Vector(0, 0, -40) + perpEyeTrace * -10 + duckOffset)
	ent:SetAngles(Angle(0, eyeAngles.y, 0))
	
	ent.Owner = ply
	ent:Spawn()
	
	ply:SetNWEntity("supersheep_entity", ent)
	
	local phys = ent:GetPhysicsObject()
	if ( !IsValid( phys ) ) then ent:Remove() return end
	
	return ent
	
end

function SWEP:Holster()
	self.LastOwner = self:GetNWEntity("lastOwner")
	return (not self.DontHolster || self.LastOwner:GetNWBool("supersheep_exploded"))
end

function SWEP:Deploy()
local VModel = self.Owner:GetViewModel()
local EnumToSeq = VModel:SelectWeightedSequence( ACT_VM_IDLE )

VModel:SendViewModelMatchingSequence( EnumToSeq )

--local VModel = self.Owner:GetViewModel()
--self:SetPlaybackRate( 0.01 )
--VModel:SendViewModelMatchingSequence( EnumToSeq )

--self.Weapon:SetPlaybackRate( 0.01 )
--self.LastOwner = self.Owner
--self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
--self.Weapon:SendWeaponAnim(ACT_VM_IDLE)
end

function SWEP:OnDrop()
	self.LastOwner = self:GetNWEntity("lastOwner")
	--print(self.Owner)
	--print(self.LastOwner)
	--self.WorldModel = "models/weapons/item_ttt_supersheep.mdl"
	--self:SetModel("models/weapons/item_ttt_supersheep.mdl")
	if CLIENT then return end
	
	if self.SheepStartTime >= 0 then 
		self:Remove()
		return
	end
	
	ent_item = ents.Create("prop_physics")
	
	local function Supersheep_PickupItem(ply, entity)
		if not IsValid(ply) || not IsValid(entity) || entity != ent_item then return true end
		ply:Give("weapon_ttt_supersheep")
		entity:Remove()
		return false
	end
	self.CancelSound = true
	self:StopSound("supersheep_wind")
	
	ent_item:SetModel("models/weapons/item_ttt_supersheep.mdl")
	ent_item:SetPos(self:GetPos() + self.LastOwner:GetAimVector() * 10)
	ent_item:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	hook.Add("PlayerUse", "Supersheep_PickupItem", Supersheep_PickupItem)
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
	if not IsValid(self.Owner) then return end
	local newWeapon = self.Owner:GetWeapons()[2]
	if (SERVER && IsValid(newWeapon)) then
		self.Owner:SelectWeapon(newWeapon:GetClass())
	end
end

function SWEP:DrawHUD()
	if self.Ent_supersheep != 0 && IsValid(self.Ent_supersheep) && self.SheepStartTime >= 0 then
		self.TimeLeft = math.Truncate(30 - (CurTime() - self.SheepStartTime),0) + 1
		if self.TimeLeft > 10 || self.TimeLeft <= -1 then return end
		if 30 - (CurTime() - self.SheepStartTime) < 0 then self.TimeLeft = 0 end 
		
		draw.RoundedBox(12, ScrW() / 2 - 20, 20, 40, 40 , Color(248, 172, 24, 250) ) 
		--surface.SetMaterial(background)
		surface.SetDrawColor(255,255,255,255)
		surface.SetFont( "CloseCaption_Bold" )
		local width, height = surface.GetTextSize( tostring(self.TimeLeft) )
		draw.DrawText(tostring(self.TimeLeft), "CloseCaption_Bold", ScrW() / 2 - (width / 2.0), 40 - (height * 0.5) , Color(255,255,255,255))
	end
end

function SWEP:Equip(newOwner)
	self:SetNWEntity("lastOwner", newOwner)
	--self.LastOwner = newOwner
end