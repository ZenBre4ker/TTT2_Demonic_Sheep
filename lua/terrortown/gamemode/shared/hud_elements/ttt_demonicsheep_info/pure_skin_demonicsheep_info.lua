local base = "pure_skin_element"

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

if SERVER then
	AddCSLuaFile()
	return
end

if CLIENT then -- CLIENT

	local healthColor  = Color(234, 41, 41)
	local controlColor1 = Color(180, 133, 0)
	local controlColor2 = Color(230, 177, 0)
	local interpColor = controlColor1
	local interpCount = 1
	local barHeight = 26
	local pad = 15
	local spaceBar = 7
	local timersize = 42

	local const_defaults = {
		basepos = {x = 0, y = 0},
		size = {w = 340, h = 2 * barHeight + 3 * spaceBar},
		minsize = {w = 340, h = 2 * barHeight + 3 * spaceBar}
	}

	function HUDELEMENT:PreInitialize()
		BaseClass.PreInitialize(self)

		local hud = huds.GetStored("pure_skin")
		if hud then
			hud:ForceElement(self.id)
		end

		-- set as fallback default, other skins have to be set to true!
		self.disabledUnlessForced = false
	end

	function HUDELEMENT:Initialize()
		self.scale = 1.0
		self.basecolor = self:GetHUDBasecolor()
		self.barHeight = barHeight * self.scale
		self.pad = pad * self.scale
		self.spaceBar = spaceBar * self.scale
		self.timersize = timersize * self.scale

		BaseClass.Initialize(self)
	end

	function HUDELEMENT:PerformLayout()
		self.basecolor = self:GetHUDBasecolor()
		self.scale = self:GetHUDScale()
		self.barHeight = barHeight * self.scale
		self.pad = pad * self.scale
		self.spaceBar = spaceBar * self.scale
		self.timersize = timersize * self.scale

		BaseClass.PerformLayout(self)
	end

	function HUDELEMENT:GetDefaults()
		const_defaults["basepos"] = {x = math.Round(ScrW() / 2 - self.size.w * 0.5), y = math.Round(ScrH() - self.size.h * 2 - self.pad)}

		return const_defaults
	end

	-- parameter overwrites
	function HUDELEMENT:IsResizable()
		return false, false
	end

	function HUDELEMENT:ShouldDraw()
		local client = LocalPlayer()
		local wep = client:GetActiveWeapon()
		return IsValid(wep) and wep:GetClass() == "weapon_ttt_demonicsheep"
	end
	-- parameter overwrites end

	function HUDELEMENT:Draw()
		local client = LocalPlayer()
		local pos = self:GetPos()
		local size = self:GetSize()
		local demonicsheep = client:GetActiveWeapon()
		local x, y = pos.x, pos.y
		local w, h = size.w, size.h
		local fontColor = util.GetDefaultColor(self.basecolor)

		-- draw bg
		self:DrawBg(x, y, w, h, self.basecolor)

		-- draw border and shadow
		self:DrawLines(x, y, w, h, self.basecolor.a)

		-- draw Health and Controlmode bar
		self:Drawdemonicsheep(x, y, w, h, fontColor, demonicsheep)

	end

	function HUDELEMENT:Drawdemonicsheep(x, y, w, h, fontColor, demonicsheep)
		local ent = demonicsheep.demonicSheepEnt

		local health = 100
		local maxHealth = 100

		if IsValid(ent) then
			health = ent:Health()
			maxHealth = ent:GetMaxHealth()
		end

		local rx, ry = x + self.spaceBar, y + self.spaceBar
		local bw, bh = w - 2 * self.spaceBar, 26 * self.scale

		--draw Health bar
		self:DrawBar(rx, ry, bw, bh, healthColor, health / maxHealth, self.scale)
		draw.AdvancedText("Health: ", "PureSkinBar", rx + self.spaceBar, ry + 1 * self.scale, fontColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, true, self.scale)
		draw.AdvancedText(tostring(health .. "/" .. tostring(maxHealth)), "PureSkinBar", rx + bw * 0.5, ry + 1 * self.scale, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_LEFT, true, self.scale)

		ry = ry + self.barHeight + self.spaceBar

		local controlState = demonicsheep.currentControlType
		local maxStates = #demonicsheep.availableControls

		if interpCount ~= controlState then
			interpCount = controlState
			interpColor = self:ColorInterp(controlColor1, controlColor2, interpCount, maxStates)
		end

		--draw ControlMode bar
		local controlTextLeft = "Control:"
		local controlTextCenter = demonicsheep.availableControls[controlState][1]
		local controlTextRight = "(" .. tostring(controlState) .. "/" .. tostring(maxStates) .. ")"
		self:DrawBar(rx, ry, bw, bh, interpColor, 1, self.scale) -- old Bar with progress p=(controlState - 1) / (maxStates - 1)
		draw.AdvancedText(controlTextLeft, "PureSkinBar", rx + self.spaceBar, ry + 1 * self.scale, fontColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, true, self.scale)
		draw.AdvancedText(controlTextCenter, "PureSkinBar", rx + bw * 0.5, ry + 1 * self.scale, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_LEFT, true, self.scale)
		draw.AdvancedText(controlTextRight, "PureSkinBar", rx + bw - self.spaceBar, ry + 1 * self.scale, fontColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_LEFT, true, self.scale)
	end

	function HUDELEMENT:ColorInterp(Color1, Color2, step, maxSteps)
		local r = Color1.r
		local g = Color1.g
		local b = Color1.b
		local a = Color1.a

		r = r + (math.Clamp(step, 1, maxSteps) - 1) * (Color2.r - r) / (maxSteps - 1)
		g = g + (math.Clamp(step, 1, maxSteps) - 1) * (Color2.g - g) / (maxSteps - 1)
		b = b + (math.Clamp(step, 1, maxSteps) - 1) * (Color2.b - b) / (maxSteps - 1)
		a = a + (math.Clamp(step, 1, maxSteps) - 1) * (Color2.a - a) / (maxSteps - 1)

		return Color(r, g, b, a)
	end
end