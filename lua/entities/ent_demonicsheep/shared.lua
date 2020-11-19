if SERVER then
	AddCSLuaFile()
end

ENT.Author 					= "ZenBreaker"
ENT.PrintName				= "Demonic Sheep"
ENT.Base 					= "base_anim"
ENT.Type 					= "anim"
ENT.AutomaticFrameAdvance 	= true
ENT.Spawnable 				= false
ENT.RenderGroup 			= RENDERGROUP_OPAQUE
ENT.Model 					= Model("models/weapons/ent_ttt_demonicsheep.mdl")

-- this is used to remove the SWEP if the sheep dies
ENT.demonicSheepSwep		= nil

-- Handling serveral SWEPs in one game
local demonicEntCounter		= 0
ENT.myId					= 0

-- localization for Translations
local ParT = LANG.GetParamTranslation
local TryT = LANG.TryTranslation

function ENT:Initialize()
	demonicEntCounter = demonicEntCounter + 1
	self.myId = demonicEntCounter

	self:SetModel(self.Model)
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_OBB) -- Needs to be an OBB as VPHYSICS don't work with multiple bones, for detailed physics spawn a ragdoll with the sheep Model or or spawn several OBBs for each physicsbone
		self:SetCollisionGroup(COLLISION_GROUP_NONE)

		local phys = self:GetPhysicsObject()
		phys:EnableGravity(false)

		self:SetHealth(100)
		self:SetMaxHealth(100)
		self:DeleteOnRemove(self.demonicSheepSwep)
	end

	self:EnableRendering(true)
	self.windSound01 = nil
	self.windSound02 = nil

	self.beganFlying = false
	self.applyPhysics = nil
	self.entryPushTime = 2
	self.speedForce = 300
	self.angleBeforeCol = nil
	self.bumpBackTimer = CurTime()
	self.bumpBackTime = 0.5
	self.bumpBackDir = Vector(0, 0, 0)
	self.moveDirection = Vector(0, 0, 0)

	self.nextTime = CurTime()

	-- Add a hook, so that everything gets rendered around that entity
	hook.Add("SetupPlayerVisibility", "demonicSheepAddToPVS" .. tostring(self.myId), function(ply, viewent)
		if IsValid(ply) and IsValid(ply:GetNWEntity("demonicSheepEnt")) then
			local sheep = ply:GetNWEntity("demonicSheepEnt")
			AddOriginToPVS(sheep:GetPos())
		end
	end)

	-- Add a Target ID to the Demonic Sheep
	hook.Add("TTTRenderEntityInfo", "demonicSheepEntityInfos" .. tostring(self.myId), function(tData)
		if self.RenderEntityInfo then
			self:RenderEntityInfo(tData)
		else
			hook.Remove("TTTRenderEntityInfo", "demonicSheepEntityInfos" .. tostring(self.myId))
		end
	end)
end

function ENT:Think()
	if CLIENT then return end -- Normally you would do the prediction here too, but somehow the entities differ and you get a big stutter while you are in Sheep Control
	if not IsValid(self.demonicSheepSwep) then self:Remove() end

	if not self.applyPhysics then return end

	if not self.beganFlying then
		self.beganFlying = true
		self:ResetSequence(self:LookupSequence(ACT_VM_PRIMARYATTACK))
	end
	local phys = self:GetPhysicsObject()
	if not phys then return end

	if phys:IsAsleep() then
		phys:Wake()
	else
		self:SetAngles(self:GetAngles()) -- Stupid Trick, that makes the physicsForces act "normal", when you don't control it

		-- Move sheep when entryPushTime got defined to have a little bit of movement at the start
		if self.applyPhysics >= CurTime() then
			local deltaTimeLeft = self.applyPhysics - CurTime()
			phys:ApplyForceCenter(self:GetAngles():Forward() * self.speedForce * (deltaTimeLeft / self.entryPushTime))
		end

		-- Generally move the sheep in the set moveDirection
		phys:ApplyForceCenter(self.moveDirection * self.speedForce)

		-- If a Collision happened, then bounce back to avoid strange collision behaviour
		if self.bumpBackTimer then
			local deltaTimeLeft = self.bumpBackTimer - CurTime()
			if deltaTimeLeft >= 0 then
				phys:ApplyForceCenter(self.bumpBackDir * self.speedForce * 2 * (deltaTimeLeft / self.bumpBackTime))
			else
				phys:SetVelocity(Vector(0,0,0))
				self.bumpBackTimer = nil
			end
		end

	end

	-- Increase Think Rate to the Maximum available, aka the next frame
	-- Reduces Lagging while observing the sheep
	if SERVER then
	self:NextThink(CurTime())
	end

	if CLIENT then
	self:SetNextClientThink(CurTime())
	end

	return true
end

function ENT:EnableRendering(bRender)
	--[[if bRender then
		self.RenderGroup = RENDERGROUP_OPAQUE
	else
		self.RenderGroup = RENDERGROUP_OTHER
	end--]]
	self.getRendered = bRender

	-- Whenever the sheep is Rendered play Sounds
	self:EnableLoopingSounds(bRender)
end

function ENT:EnableLoopingSounds(bSounds)
	if bSounds then
		self.windSound01 = self:StartLoopingSound("demonicsheep_wind_background")
		self.windSound02 = self:StartLoopingSound("demonicsheep_wind_ominous")
	else
		if self.windSound01 then
		self:StopLoopingSound(self.windSound01)
		end
		if self.windSound02 then
		self:StopLoopingSound(self.windSound02)
		end
	end
end

function ENT:EnablePhysicsControl(bControl, entryPushTime)
	self.entryPushTime = entryPushTime or 0
	if bControl then
		self.applyPhysics = CurTime() + self.entryPushTime
	else
		self.applyPhysics = nil
	end
end

function ENT:SetMoveDirection(moveDirection)
	self.moveDirection = moveDirection
end

-- ENTITY:PhysicsUpdate( PhysObj phys )
function ENT:PhysicsUpdate(phys)
	if self.angleBeforeCol then
		self:SetAngles(self.angleBeforeCol)
		self.angleBeforeCol = nil
	end
	phys:AddAngleVelocity(-phys:GetAngleVelocity())
end

-- ENTITY:PhysicsCollide( table colData, PhysObj collider )
function ENT:PhysicsCollide(colData, collider)
	self.angleBeforeCol = self:GetAngles()
	self.bumpBackDir = -colData.HitNormal
	self.bumpBackTimer = CurTime() + self.bumpBackTime
end

function ENT:OnTakeDamage(dmgInfo)
	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end

	newHealth = self:Health() - damage
	if newHealth <= 0 then
		-- Stop Sounds before removing
		self:EnableLoopingSounds(false)
		self:Remove()
	else
		self:SetHealth(newHealth)
	end

	-- start painting blood decals
	util.StartBleeding(self, damage, 5)

	-- Apply damage Forces as if you would hit a wall over time
	local damageDir = dmgInfo:GetDamageForce()
	damageDir:Normalize()
	self.bumpBackDir = damageDir
	self.bumpBackTimer = CurTime() + self.bumpBackTime

end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
	-- Stop Sounds before removing
	self:EnableLoopingSounds(false)

	self:CreateRagdoll()

	hook.Remove("SetupPlayerVisibility", "demonicSheepAddToPVS" .. tostring(self.myId))
	hook.Remove("TTTRenderEntityInfo", "demonicSheepEntityInfos" .. tostring(self.myId))
	return
end

function ENT:CreateRagdoll()
	if CLIENT then return end
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end

	rag:SetPos(self:GetPos())
	rag:SetModel(self:GetModel())
	rag:SetAngles(self:GetAngles())
	rag:SetColor(self:GetColor())

	rag:Spawn()
	rag:Activate()

	-- nonsolid to players, but can be picked up and shot
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	rag:SetCustomCollisionCheck(true)

	-- position the bones
	local num = (rag:GetPhysicsObjectCount() - 1)

	for i = 0, num do
		local bone = rag:GetPhysicsObjectNum(i)

		if IsValid(bone) then
			local bp, ba = ply:GetBonePosition(rag:TranslatePhysBoneToBone(i))

			if bp and ba then
				bone:SetPos(bp)
				bone:SetAngles(ba)
			end
		end
	end
end

function ENT:RenderEntityInfo(tData)
	local ent = tData:GetEntity()
	if ent:GetClass() ~= "ent_demonicsheep" then return end

	-- enable targetID rendering
	tData:EnableText()

	-- add title and subtitle to the focused ent
	local h_string, h_color = util.HealthToString(ent:Health(), ent:GetMaxHealth())

	local roleColor = COLOR_WHITE
	if IsValid(ent:GetOwner()) then
		roleColor = ent:GetOwner():GetRoleColor()
	end
	tData:SetTitle(ent.PrintName,roleColor)

	tData:SetSubtitle(
		TryT(h_string),
		h_color
	)
end

function ENT:Draw()
	if not IsValid(self) or not self.getRendered then return end
	self:DrawModel()
end
--[[

if SERVER then
	AddCSLuaFile()
end

ENT.Base 		= "base_anim"
ENT.Type 		= "anim"
ENT.AutomaticFrameAdvance = true
ENT.Spawnable 		= false
ENT.AdminSpawnable 	= false
ENT.PrintName		= "demonicsheep"
ENT.isInitialized = false

local collided = false
local ent = self

function ENT:Initialize()
	self.isInitialized = true	

	self:SetNWBool("exploded", false)
	self.MovementMode = 0
	self.SpawnTime = CurTime()
	self.First = false
	self.Hits = 0
	self.TargetReached = false
	collided = false
	self.CollideCount = 0
	self.Drop = false
	self:SetModel( "models/weapons/ent_ttt_demonicsheep.mdl" )
	self:SetHealth(100)
	self.Boost = false
	self.IsBoosting = false
	self.Minified = false
	self.Minify = false
	self.MinifiedStart = 0
	
	test = self:PhysicsInit( SOLID_VPHYSICS )
	local phys = self:GetPhysicsObject()
	if ( IsValid( phys ) ) then 
		self:GetPhysicsObject():SetMass( 0.5 ) 
	end
	
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	

	if SERVER then
		self:SetModelScale( self:GetModelScale() * 0.25)
	end
	
	if(SERVER) then
		net.Start("InitializedDemonicSheep")
		net.WriteEntity(self)
		net.Send(self.Owner)
		
		self.BigHitbox = ents.Create("prop_physics")
		self.BigHitbox:SetModel("models/props_c17/oildrum001_explosive.mdl")
		self.BigHitbox:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self.BigHitbox:SetParent(self)
		self.BigHitbox:SetPos(self:GetPos() - self:GetAngles():Forward() * 30 + self:GetAngles():Up() * 10 )
		
		self.BigHitbox:SetNoDraw(true)
		self.BigHitbox:SetMaterial("models/building_correct", true)
		--self.BigHitbox:SetCollisionGroup()
		--self.BigHitbox:SetMoveType(MOVETYPE_VPHYSICS)
		--self.BigHitbox:SetSolid(SOLID_VPHYSICSqqqq)
		
		self.BigHitbox:Spawn()
		
		self.BigHitbox:SetModelScale( self.BigHitbox:GetModelScale() * 1.2)
		self.BigHitbox:Activate()
		
		--self.BigHitbox:PhysicsInit( SOLID_VPHYSICS )
		--local phys2 = self.BigHitbox:GetPhysicsObject()
		--if ( IsValid( phys2 ) ) then 
		--	self.BigHitbox:GetPhysicsObject():SetMass( 0.5 ) 
		--end
		
		hook.Add("EntityTakeDamage", "demonicsheep_BiggerHitbox" .. tostring(self), function(target, dmg)
			if target == self.BigHitbox then
				self:TakeDamage(dmg:GetDamage(), dmg:GetAttacker(), dmg:GetInflictor())
				return true
			end
		end)
		
		local capeLeftBone = self:LookupBone("demonicsheep_Ear_Left")
		local capeRightBone = self:LookupBone("demonicsheep_Cape_Right")
		
		self.TrailLeft = ents.Create("prop_physics")
		self.TrailLeft:SetModel("models/props_junk/PopCan01a.mdl")
		--self.TrailLeft:SetMaterial("models/building_correct", true)
		self.TrailLeft:SetPos(self:GetPos() - self:GetAngles():Forward() * 5 + self:GetAngles():Up() * 13 + self:GetAngles():Right() * 6)
		self.TrailLeft:SetParent(self, capeLeftBone)
		self.TrailLeft:SetNoDraw(true)
		
		
		self.TrailRight = ents.Create("prop_physics")
		self.TrailRight:SetModel("models/props_junk/PopCan01a.mdl")
		--self.TrailLeft:SetMaterial("models/building_correct", true)
		self.TrailRight:SetPos(self:GetPos() - self:GetAngles():Forward() * 5 + self:GetAngles():Up() * 13 + self:GetAngles():Right() * -6)
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
	self:Explode()
end

function ENT:Explode()
	if self.CollideCount != 0 then return end
	--print("collided")
	--self.Owner:EmitSound("weapons/crossbow/hitbod1.wav", 75, 100, 0.1)
	self.CollideCount = 1
	self:SetNWBool("exploded", true)
	--self:SetMoveType(MOVETYPE_NONE)
	self:SetNoDraw(true)
	--util.BlastDamage( self, self.Owner, self:GetPos(), 200, 125 )
	
	if CLIENT then return end
	local explode = ents.Create( "env_explosion" ) -- creates the explosion
	explode:SetPos( self:GetPos() )

	
	explode:SetOwner( self.Owner ) -- this sets you as the person who made the explosion
	explode:SetKeyValue( "spawnflags", 129 ) --Setting the key values of the explosion
	explode:SetKeyValue( "iMagnitude", "280" ) -- the magnitude
	explode:SetKeyValue( "iRadiusOverride", "250" )
	explode:Spawn() --this actually spawns the explosion
	explode:Fire( "explode", "", 0 )
	explode:EmitSound( "weapon_AWP.Single", 400, 400 ) --
	
	local interpolValue =  math.min(CurTime() - self.MinifiedStart, 1)
	
	self.BigHitbox:Remove()
	
	if self.Minified then
		util.BlastDamage(self.CorrespondingWeapon, self.Owner, self:GetPos(), 50 * interpolValue + 220 * (1- interpolValue), 100 * interpolValue + 200 * (1- interpolValue))
	else
		util.BlastDamage(self.CorrespondingWeapon, self.Owner, self:GetPos(), 220 * interpolValue + 50 * (1- interpolValue), 200 * interpolValue + 100 * (1- interpolValue))
	end
	
	timer.Create( "demonicsheep_explosion_delay", 1.5, 1, function()
		if IsValid(self) && IsValid(self.Owner) && IsValid(self.Owner:GetActiveWeapon()) then
			--print(self.Owner)
			-- local newWeapon = self.Owner:GetWeapons()[2]
			-- if (SERVER && IsValid(newWeapon)) then
				-- self.Owner:SelectWeapon(newWeapon:GetClass())
			-- end
			self.Owner:SetNWBool("demonicsheep_removed", true)
			self.Owner:GetActiveWeapon():Remove()
			self:Remove()
		end
	end )
end


function ENT:Think()
	if SERVER && (not IsValid(self.Owner) || not self.Owner:Alive()) then
		self:Explode()
	end

	self:Fly()

	--self:SetPos(Vector(500, 500, -30))
	--self:SetAngles(Angle(0, 0, 0))

	self:NextThink( CurTime() + 0.033 ) -- Set the tickrate to 33 ticks/s. Maybe this prevents laggs.

	if not self:GetNWBool("exploded") then return true end
	if (IsValid(self) && IsValid(self.CorrespondingWeapon)) then
		self.CorrespondingWeapon.CancelSound = true
		--self.CorrespondingWeapon:StopSound("demonicsheep_wind")
	end
	--self.Owner:GetActiveWeapon():EmitSound("weapons/crossbow/hitbod1.wav")

	if CLIENT then 
		return true 
	end
	self:SetMoveType(MOVETYPE_NONE)
	--self:Remove()
end

function ENT:Fly()

	if self.Minify then
		if not self.Minified then
		
			self.MinifiedStart = CurTime()
			self.Minified = true
			self.Owner:SetNWBool("demonicsheep_small", true)
		
			if SERVER then
				self:SetModelScale( self:GetModelScale() * 0.25, 1)

				self.BigHitbox:SetPos(Vector(0, 0, 0))
				self.BigHitbox:SetModelScale( self.BigHitbox:GetModelScale() * 0.25, 1)
				self.BigHitbox:SetPos(Vector(-7.5, 0, 0) + Vector(0, 0, 2.5))
			
			
				self.TrailLeft:SetPos(self:GetPos() - self:GetAngles():Forward() * 1.25 + self:GetAngles():Up() * 3.25 + self:GetAngles():Right() * 1.5)
				self.TrailRight:SetPos(self:GetPos() - self:GetAngles():Forward() * 1.25 + self:GetAngles():Up() * 3.25 + self:GetAngles():Right() * -1.5)
			
				--self.TrailLeft:SetPos(Vector(1.25, 0, 0) + Vector(0, 0, 3.25) + Vector(0, 1.5, 0))
				--self.TrailRight:SetPos(Vector(1.25, 0, 0) + Vector(0, 0, 3.25) + Vector(0, -1.5, 0))
			end
		else
	
			self.MinifiedStart = CurTime()
			self.Minified = false
			self.Owner:SetNWBool("demonicsheep_small", false)
		
			if SERVER then
				self:SetModelScale( self:GetModelScale() * 4, 1)

				self.BigHitbox:SetPos(Vector(0, 0, 0))
				self.BigHitbox:SetModelScale( self.BigHitbox:GetModelScale() * 4, 1)
				self.BigHitbox:SetPos(Vector(-30, 0, 0) + Vector(0, 0, 10))
			
				self.TrailLeft:SetPos(self:GetPos() - self:GetAngles():Forward() * 5 + self:GetAngles():Up() * 13 + self:GetAngles():Right() * 6)
				self.TrailRight:SetPos(self:GetPos() - self:GetAngles():Forward() * 5 + self:GetAngles():Up() * 13 + self:GetAngles():Right() * -6)
			end
		end
		self.Minify = false
	end

	--handle fly animation
	if(not self.First) then
		if SERVER then
			self:SetModelScale( self:GetModelScale() * 4)
			--self.BigHitbox:SetModelScale(self.BigHitbox:GetModelScale() * 4, 1)
		end

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
		if self.Minified then
			phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 100)
		else
			phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 200)
		end
	else
		if self.Minified then
			phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 50)
		else
			phys:ApplyForceCenter(self.Owner:GetEyeTrace().Normal * 100)
		end
	end
end

function ENT:OnTakeDamage(damage)
	if damage:GetDamage() <= 0 then return end

	self:SetHealth(self:Health() - damage:GetDamage())

	if (self:Health() <= 0) && SERVER then
		self:Explode()
	end
end

function ENT:Remove()
	hook.Remove("EntityTakeDamage", "demonicsheep_BiggerHitbox" .. tostring(self))
end

function ENT:Draw()
	render.OverrideDepthEnable( true, true )
	self:DrawModel()
	--if not IsValid(self.Owner) || LocalPlayer() == self.Owner then return end
	--if not IsValid(self.Owner) then return end
	local pos = self:GetPos()
	if self.Minified then
		pos = pos + Vector(0, 0, 15)
	else
		pos = pos + Vector(0, 0, 30)
	end
	local ang = Angle(0, LocalPlayer():GetAngles().y - 90, 90)
	surface.SetFont("demonicsheep_Font")
	local width = 200 / 1.5
	
	render.OverrideDepthEnable( false, false )
	cam.Start3D2D(pos, ang, 0.3)
		draw.RoundedBox( 5, -width / 2, -5, 100 * 2 / 1.5, 15, Color(181, 27, 19, 220) )
		draw.RoundedBox( 5, -width / 2 , -5, self:Health() * 2 / 1.5, 15, Color(26, 182, 19, 220) )
		draw.SimpleText( tostring(self:Health()) .. " / 111", "demonicsheep_Font", 0, -7, Color(255,255,255,255), TEXT_ALIGN_CENTER)
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

--]]