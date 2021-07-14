if not TTT2 then return end

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
local TryT = LANG.TryTranslation

function ENT:SetupDataTables()
	self:NetworkVar( "Bool", 0, "getRendered" )
end

-- Always send data to clients
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:Initialize()
	demonicEntCounter = demonicEntCounter + 1
	self.myId = demonicEntCounter

	-- Initialize Sheep Model and Physics
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

	-- Other Variables
	self:EnableRendering(false)
	self.windSound01 = nil
	self.windSound02 = nil

	self.beganFlying = false
	self.isIdle = false
	self.applyPhysics = nil
	self.entryPushTime = 2
	self.speedForce = 300
	self.angleBeforeCol = nil
	self.bumpBackTimer = CurTime()
	self.bumpBackTime = 0.5
	self.bumpBackDir = Vector(0, 0, 0)
	self.moveDirection = Vector(0, 0, 0)

	self.nextTime = CurTime()

	-- Add a Target ID to the Demonic Sheep
	hook.Add("TTTRenderEntityInfo", "demonicSheepEntityInfos" .. tostring(self.myId), function(tData)
		if self.RenderEntityInfo then
			self:RenderEntityInfo(tData)
		else
			hook.Remove("TTTRenderEntityInfo", "demonicSheepEntityInfos" .. tostring(self.myId))
		end
	end)
end

-- In Combination with the "TTTRenderEntityInfo"-Hook display target ID
function ENT:RenderEntityInfo(tData)
	local ent = tData:GetEntity()
	if ent:GetClass() ~= "ent_demonicsheep" then return end

	-- Enable targetID rendering
	tData:EnableText()

	-- Add title and subtitle to the focused ent
	local h_string, h_color = util.HealthToString(ent:Health(), ent:GetMaxHealth())

	local roleColor = COLOR_WHITE
	if IsValid(ent:GetOwner()) then
		roleColor = ent:GetOwner():GetRoleColor()
	end

	-- TODO: Enable Translations for Demonic Sheep Name
	tData:SetTitle(ent.PrintName,roleColor)

	tData:SetSubtitle(
		TryT(h_string),
		h_color
	)
end

function ENT:GetDisguiserTarget()
	return self
end

-- In Think we handle only Physics-Interactions
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

-- Used to have the sheep pushed out after launch
function ENT:EnablePhysicsControl(bControl, entryPushTime)
	self.entryPushTime = entryPushTime or 0
	if bControl then
		self.applyPhysics = CurTime() + self.entryPushTime
	else
		self.applyPhysics = nil
	end
end

-- Is used to move the sheep, by setting a moveDirection-Vector
function ENT:SetMoveDirection(moveDirection)
	self.moveDirection = moveDirection
	if moveDirection:Length() == 0 then
		if not self.isIdle then
			self.isIdle = true
			self:SetSequence("idle")
		end
	elseif self.isIdle then
		self.isIdle = false
		self:SetSequence("fly")
	end
end

-- ENTITY:PhysicsCollide(table colData, PhysObj collider)
function ENT:PhysicsCollide(colData, collider)
	self.angleBeforeCol = self:GetAngles()
	self.bumpBackDir = -colData.HitNormal
	self.bumpBackTimer = CurTime() + self.bumpBackTime
end

-- ENTITY:PhysicsUpdate(PhysObj phys)
function ENT:PhysicsUpdate(phys)
	if self.angleBeforeCol then
		self:SetAngles(self.angleBeforeCol)
		self.angleBeforeCol = nil
	end
	phys:AddAngleVelocity(-phys:GetAngleVelocity())
end

-- Renders the entity depending on self.getRendered
function ENT:Draw()
	if not IsValid(self) or not self:GetgetRendered() then return end
	self:DrawModel()
end

function ENT:EnableRendering(bRender)
	self:SetgetRendered(bRender)

	-- Whenever the sheep is Rendered play Sounds
	self:EnableLoopingSounds(bRender)
end

-- Starts and stops movement-sounds
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

function ENT:OnTakeDamage(dmgInfo)
	local damage = dmgInfo:GetDamage()
	if damage <= 0 then return end

	newHealth = self:Health() - damage
	if newHealth <= 0 then
		-- Stop Sounds before removing (twice for safety)
		self:EnableLoopingSounds(false)
		self:Remove()
	else
		self:SetHealth(newHealth)
	end

	-- start painting blood decals
	util.StartBleeding(self, damage, 5)

	-- Apply damage Forces the same as if you would hit a wall (so pushed back over time)
	local damageDir = dmgInfo:GetDamageForce()
	damageDir:Normalize()
	self.bumpBackDir = damageDir
	self.bumpBackTimer = CurTime() + self.bumpBackTime
end


function ENT:OnRemove()
	-- Stop Sounds before removing (twice for safety)
	self:EnableLoopingSounds(false)

	self:CreateRagdoll()

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

	-- Nonsolid to players, but can be picked up and shot
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	rag:SetCustomCollisionCheck(true)

	-- Position the bones
	local num = (rag:GetPhysicsObjectCount() - 1)

	for i = 0, num do
		local bone = rag:GetPhysicsObjectNum(i)

		if IsValid(bone) then
			local bp, ba = self:GetBonePosition(rag:TranslatePhysBoneToBone(i))

			if bp and ba then
				bone:SetPos(bp)
				bone:SetAngles(ba)
			end
		end
	end
end
