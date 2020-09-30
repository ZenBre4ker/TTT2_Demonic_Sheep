if SERVER then
	AddCSLuaFile()
end

ENT.Base 		= "base_anim"
ENT.Type 		= "anim"
ENT.AutomaticFrameAdvance = true
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false
ENT.PrintName		= "Detective Observation"

local collided = false
local ent = self

function ENT:Initialize()

	self:SetNWBool("removed", false)
	
	self.MovementMode = 0
	self.SpawnTime = CurTime()
	self.First = false

	collided = false
	self.CollideCount = 0
	self.Drop = false
	self:SetModel( "models/weapons/ent_ttt_detective_supersheep.mdl" )
	
	self:Activate()
	
	self:SetHealth(100)
	if IsValid(self.CorrespondingWeapon) then
		self:SetHealth(self.CorrespondingWeapon:Clip1())
	end
	
	test = self:PhysicsInit( SOLID_VPHYSICS )
	local phys = self:GetPhysicsObject()
	if ( IsValid( phys ) ) then 
		self:GetPhysicsObject():SetMass( 0.5 ) 
	end
	
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	if(SERVER) then
		self:SetModelScale(self:GetModelScale() * 0.25)
	
		self.BigHitbox = ents.Create("prop_physics")
		self.BigHitbox:SetModel("models/props_c17/oildrum001_explosive.mdl")
		self.BigHitbox:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self.BigHitbox:SetPos(self:GetPos() - self:GetAngles():Forward() * 7.5 + self:GetAngles():Up() * 2.5 )
		self.BigHitbox:SetParent(self)
		self.BigHitbox:SetNoDraw(true)
		self.BigHitbox:SetMaterial("models/building_correct", true)
		--self.BigHitbox:SetCollisionGroup()
		--self.BigHitbox:SetMoveType(MOVETYPE_VPHYSICS)
		--self.BigHitbox:SetSolid(SOLID_VPHYSICSqqqq)
		
		self.BigHitbox:Spawn()
		
		self.BigHitbox:SetModelScale( self.BigHitbox:GetModelScale() * 0.3)
		self.BigHitbox:Activate()
		
		--self.BigHitbox:PhysicsInit( SOLID_VPHYSICS )
		--local phys2 = self.BigHitbox:GetPhysicsObject()
		--if ( IsValid( phys2 ) ) then 
		--	self.BigHitbox:GetPhysicsObject():SetMass( 0.5 ) 
		--end
		
		hook.Add("EntityTakeDamage", "Supersheep_Detective_BiggerHitbox" .. tostring(self), function(target, dmg)
			if target == self.BigHitbox then
				--print(dmg:GetDamage())
				self:TakeDamage(dmg:GetDamage(), dmg:GetAttacker(), dmg:GetInflictor())
				return true
			end
		end)
		
		local capeLeftBone = self:LookupBone("Supersheep_Ear_Left")
		local capeRightBone = self:LookupBone("Supersheep_Cape_Right")
		
		self.TrailLeft = ents.Create("prop_physics")
		self.TrailLeft:SetModel("models/props_junk/PopCan01a.mdl")
		--self.TrailLeft:SetMaterial("models/building_correct", true)
		self.TrailLeft:SetPos(self:GetPos() - self:GetAngles():Forward() * 1.25 + self:GetAngles():Up() * 3.25 + self:GetAngles():Right() * 1.5)
		self.TrailLeft:SetParent(self, capeLeftBone)
		self.TrailLeft:SetNoDraw(true)
		
		
		self.TrailRight = ents.Create("prop_physics")
		self.TrailRight:SetModel("models/props_junk/PopCan01a.mdl")
		--self.TrailLeft:SetMaterial("models/building_correct", true)
		self.TrailRight:SetPos(self:GetPos() - self:GetAngles():Forward() * 1.25 + self:GetAngles():Up() * 3.25 + self:GetAngles():Right() * -1.5)
		self.TrailRight:SetParent(self, capeRightBone)
		self.TrailRight:SetNoDraw(true)
	
		
		--self.TrailLeft:FollowBone(self, capeLeftBone)
		--self.TrailRight:FollowBone(self, capeRightBone)
	end
	
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:PhysicsCollide(data, phys)
	if CurTime() - self.SpawnTime < 0.9 then 
		--self:GetPhysicsObject():ApplyForceCenter(Vector(0, 0, 500))
		local ownerAngles = self.Owner:EyeAngles()
		self.Owner:SetEyeAngles(Angle(ownerAngles.p - 1.5, ownerAngles.y, ownerAngles.r))
		return 
	end
	
	if IsValid(data.HitEntity) && data.HitEntity:IsPlayer() then
		local dmg = DamageInfo()
		dmg:SetAttacker(self.Owner)
		dmg:SetDamage(10)
		dmg:SetDamageForce(self:GetVelocity()*100)
		dmg:SetInflictor(self.CorrespondingWeapon)
		dmg:SetDamageType(DMG_VEHICLE)
		data.HitEntity:TakeDamageInfo(dmg)
		self:SetHealth(self:Health() - 10)
	else
		self:SetHealth(self:Health() - 10)
	end
	
	--self:EmitSound("weapons/crossbow/hitbod1.wav")
	self.CorrespondingWeapon:EmitSound("weapons/crossbow/hitbod1.wav")
	
	self.CorrespondingWeapon:ResetSheep()
	net.Start("TTTSSRESET")
	net.WriteEntity(self.CorrespondingWeapon)
	net.Send(self.Owner)
	
	
	
	if (self:Health() <= 0) then
		self.Owner:GetActiveWeapon():Remove()
	end
	self:RemoveFromWorld()

end

function ENT:RemoveFromWorld()
	if self.CollideCount != 0 then return end

	self.CollideCount = 1
	self:SetNWBool("removed", true)
	--self:SetMoveType(MOVETYPE_NONE)
	self:SetNoDraw(true)
	self.CorrespondingWeapon.CancelSound = true

	self.CorrespondingWeapon:SetClip1(self:Health())
	
	--util.BlastDamage( self, self.Owner, self:GetPos(), 200, 125 )
	
	--self.Owner:GetActiveWeapon():Remove()
	if SERVER then 
		self.Owner:SetNWBool("supersheep_removed", true)
		self.Owner:StopSound("supersheep_wind")
		self:Remove() 
	end

end


function ENT:Think()
if SERVER && (not IsValid(self.Owner) || not self.Owner:Alive()) then
	self:RemoveFromWorld()
end

self:Fly()

--self:SetPos(Vector(500, 500, -30))
--self:SetAngles(Angle(0, 0, 0))

self:NextThink( CurTime() + 0.033 ) -- Set the tickrate to 33 ticks/s. Maybe this prevents laggs.

if not self:GetNWBool("removed") then return true end
if (IsValid(self) && IsValid(self.CorrespondingWeapon)) then
	self.CorrespondingWeapon.CancelSound = true
end
--self.Owner:GetActiveWeapon():EmitSound("weapons/crossbow/hitbod1.wav")

if CLIENT then return true end
self:SetMoveType(MOVETYPE_NONE)
--self:Remove()

end

function ENT:Fly()
--handle fly animation
if(not self.First) then
	local sequence = self:LookupSequence( ACT_VM_PRIMARYATTACK  )
	self:ResetSequence( sequence )
	self.First = true
end

if CLIENT then return end
local phys = self:GetPhysicsObject()	
phys:EnableGravity(false)

eyeAngles = self.Owner:EyeAngles()
if CurTime() - self.SpawnTime > 1.0 then
	self:SetAngles(eyeAngles)
else
	self:SetAngles(eyeAngles)
end

if self.Boost then 
	self.Boost = false
	phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 160)
else
	phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 40)
end

end

function ENT:OnTakeDamage(damage)
	if damage:GetDamage() <= 0 then return end

	self:SetHealth(self:Health() - damage:GetDamage())
	
	if (self:Health() <= 0) && SERVER then
		self.Owner:GetActiveWeapon():Remove()
		self:RemoveFromWorld()
	end
end

function ENT:Remove()
	hook.Remove("EntityTakeDamage", "Supersheep_Detective_BiggerHitbox" .. tostring(self))
end

function ENT:Draw()
	if LocalPlayer() == self.Owner then
		render.OverrideDepthEnable( true, true )
		self:DrawModel()
		--if not IsValid(self.Owner) || LocalPlayer() == self.Owner then return end
		--if not IsValid(self.Owner) then return end
		
		local pos = self:GetPos() + Vector(0, 0, 20)
		
		-- if LocalPlayer() == self.Owner then
			-- pos = self:GetPos() + Vector(0, 0, 5) + LocalPlayer():GetAimVector() * 100
		-- end
		
		local ang = Angle(0, LocalPlayer():GetAngles().y - 90, 90)
		surface.SetFont("Small_Supersheep_Font")
		local width = 100 / 1.5
		
		render.OverrideDepthEnable( false, false )
		cam.Start3D2D(pos, ang, 0.3)
			draw.RoundedBox( 2, -width / 2, -5, 50 * 2 / 1.5, 9, Color(181, 27, 19, 220) )
			draw.RoundedBox( 2, -width / 2 , -5, self:Health() / 1.5, 9, Color(26, 182, 19, 220) )
			draw.SimpleText( tostring(self:Health()) .. " / 100", "Small_Supersheep_Font", 0, -7, Color(255,255,255,255), TEXT_ALIGN_CENTER)
		cam.End3D2D()
		
		render.OverrideDepthEnable( true, true )
		render.OverrideColorWriteEnable( true, false)
		cam.Start3D2D(pos, ang, 0.3)
			draw.RoundedBox( 2, -width / 2, -5, 50 * 2 / 1.5, 9, Color(0, 0, 0, 255) )
			--render.OverrideColorWriteEnable( true, true)
			
			render.OverrideColorWriteEnable( false, false)
			render.OverrideDepthEnable( false, false )
		cam.End3D2D()
		
		cam.Start3D()
		cam.End3D()
		return
	end
	
	render.OverrideDepthEnable( true, true )
	self:DrawModel()
	--if not IsValid(self.Owner) || LocalPlayer() == self.Owner then return end
	--if not IsValid(self.Owner) then return end
	
	local pos = self:GetPos() + Vector(0, 0, 20)
	
	-- if LocalPlayer() == self.Owner then
		-- pos = self:GetPos() + Vector(0, 0, 5) + LocalPlayer():GetAimVector() * 100
	-- end
	
	local ang = Angle(0, LocalPlayer():GetAngles().y - 90, 90)
	surface.SetFont("Supersheep_Font")
	local width = 200 / 1.5
	
	render.OverrideDepthEnable( false, false )
	cam.Start3D2D(pos, ang, 0.3)
		draw.RoundedBox( 5, -width / 2, -5, 100 * 2 / 1.5, 15, Color(181, 27, 19, 220) )
		draw.RoundedBox( 5, -width / 2 , -5, self:Health() * 2 / 1.5, 15, Color(26, 182, 19, 220) )
		draw.SimpleText( tostring(self:Health()) .. " / 100", "Supersheep_Font", 0, -7, Color(255,255,255,255), TEXT_ALIGN_CENTER)
	cam.End3D2D()
	
	render.OverrideDepthEnable( true, true )
	render.OverrideColorWriteEnable( true, false)
	cam.Start3D2D(pos, ang, 0.3)
		draw.RoundedBox( 5, -width / 2, -5, 100 * 2 / 1.5, 15, Color(0, 0, 0, 255) )
		--render.OverrideColorWriteEnable( true, true)
		
		render.OverrideColorWriteEnable( false, false)
		render.OverrideDepthEnable( false, false )
	cam.End3D2D()
	
	cam.Start3D()
	cam.End3D()
end