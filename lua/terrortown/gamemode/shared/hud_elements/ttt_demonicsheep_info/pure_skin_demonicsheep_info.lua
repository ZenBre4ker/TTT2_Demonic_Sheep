local base = 'pure_skin_element'

DEFINE_BASECLASS(base)

HUDELEMENT.Base = base

if CLIENT then -- CLIENT
    local const_defaults = {
        basepos = {x = 0, y = 0},
        size = {w = 340, h = 97},
        minsize = {w = 340, h = 97}
    }

    local barColor = Color(205, 155, 0, 255)
    local timerColor = Color(234, 41, 41)
    local pad = 15
    local timersize = 42
    
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
        self.pad = pad * self.scale
        self.timersize = timersize * self.scale

		BaseClass.Initialize(self)
    end

    function HUDELEMENT:PerformLayout()
        self.basecolor = self:GetHUDBasecolor()
        self.scale = self:GetHUDScale()
        self.pad = pad * self.scale
        self.timersize = timersize * self.scale

		BaseClass.PerformLayout(self)
	end
    
    function HUDELEMENT:GetDefaults()
		const_defaults['basepos'] = {x = math.Round(ScrW() / 2 - self.size.w * 0.5), y = math.Round(ScrH() - self.size.h - self.pad)}

		return const_defaults
	end

	-- parameter overwrites
	function HUDELEMENT:IsResizable()
		return false, false
    end

    function HUDELEMENT:ShouldDraw()
        local c = LocalPlayer()
        local demonicsheepWep = c.demonicsheep
        return IsValid(demonicsheepWep) and IsValid(demonicsheepWep.Ent_demonicsheep) and demonicsheepWep.SheepStartTime >= 0
	end
    -- parameter overwrites end

    function HUDELEMENT:Drawdemonicsheep(x, y, w, h, fontColor, demonicsheep)
        --draw timer
        local timeLeft = math.max(math.Truncate(30 - (CurTime() - demonicsheep.SheepStartTime),0) + 1, 0)
        local timerX = x + w * 0.5 - self.timersize * 0.5
        local timerY = y - self.pad - self.timersize
        self:DrawBg(timerX, timerY, self.timersize, self.timersize, timerColor)
        self:DrawLines(timerX, timerY, self.timersize, self.timersize, self.basecolor.a)
        draw.AdvancedText(tostring(timeLeft), "PureSkinTimeLeft", timerX + self.timersize * 0.5, timerY + self.timersize * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true, self.scale)


        local rx, ry = x + self.pad, y + self.pad
        local bw, bh = w - 2 * self.pad, 26 * self.scale
        --draw boost bar
        self:DrawBar(rx, ry, bw, bh, barColor, demonicsheep.Boost / demonicsheep.MaxBoost, self.scale)
        draw.AdvancedText("R - Boost", "PureSkinBar", rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true, self.scale)

        ry = ry + bh + self.pad

        --draw minify bar
        local text = demonicsheep.Minified and "Right Click - Magnify" or "Right Click - Minify"
        self:DrawBar(rx, ry, bw, bh, barColor, math.min(CurTime() - demonicsheep.LastSizeChange, 5.0) / 5.0, self.scale)
        draw.AdvancedText(text, "PureSkinBar", rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true, self.scale)

    end

    function HUDELEMENT:DrawObserverSheep(x, y, w, h, fontColor, demonicsheep)
        local rx, ry = x + self.pad, y + self.pad
        local bw, bh = w - 2 * self.pad, 26 * self.scale
        --draw boost bar
        self:DrawBar(rx, ry, bw, bh, barColor, demonicsheep.Boost / demonicsheep.MaxBoost, self.scale)
        draw.AdvancedText("R - Boost", "PureSkinBar", rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true, self.scale)

        ry = ry + bh + self.pad

        --draw minify bar
        self:DrawBar(rx, ry, bw, bh, barColor, math.min(CurTime() - demonicsheep.LastTrack, 1) / 1.0, self.scale)
        draw.AdvancedText("Left Click - Track", "PureSkinBar", rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true, self.scale)

    end

	function HUDELEMENT:Draw()
		local client = LocalPlayer()
		local pos = self:GetPos()
		local size = self:GetSize()
		local x, y = pos.x, pos.y
		local w, h = size.w, size.h
        local demonicsheep = client.demonicsheep
        local fontColor = self:GetDefaultFontColor(self.basecolor)

		-- draw bg
        self:DrawBg(x, y, w, h, self.basecolor)
        
        -- draw border and shadow
        self:DrawLines(x, y, w, h, self.basecolor.a)

        if demonicsheep:GetClass() == "weapon_ttt_demonicsheep" then
            self:Drawdemonicsheep(x, y, w, h, fontColor, demonicsheep)
        else
            self:DrawObserverSheep(x, y, w, h, fontColor, demonicsheep)
        end

    end
end