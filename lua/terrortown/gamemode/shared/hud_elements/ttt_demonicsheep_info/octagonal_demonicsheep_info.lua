local base = 'octagonal_element'

DEFINE_BASECLASS(base)
local element = hudelements.GetStored(base)
if not element then return end

HUDELEMENT.Base = base

if CLIENT then -- CLIENT
    local barheight = 40
    local timersize = barheight
    local gap = 5
    local timerFont = "OctagonalBar"
    local barFont = "OctagonalBar"

    local const_defaults = {
        basepos = {x = 0, y = 0},
        size = {w = 350, h = 2 * barheight},
        minsize = {w = 350, h = 2 * barheight}
    }
    
    function HUDELEMENT:PreInitialize()
        BaseClass.PreInitialize(self)
        
        local hud = huds.GetStored("octagonal")
        if hud then
            hud:ForceElement(self.id)
        end

        -- set as NOT fallback default
        self.disabledUnlessForced = true
	end

    function HUDELEMENT:Initialize()
		self.scale = 1.0
        self.basecolor = self:GetHUDBasecolor()
        self.timersize = timersize * self.scale
        self.barheight = barheight * self.scale
        self.gap = gap * self.scale

		BaseClass.Initialize(self)
    end

    function HUDELEMENT:PerformLayout()
        self.basecolor = self:GetHUDBasecolor()
        self.scale = self:GetHUDScale()
        self.timersize = timersize * self.scale
        self.barheight = barheight * self.scale
        self.gap = gap * self.scale

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
        local rx, ry = x, y
        local bw, bh = w, self.barheight
        
        --draw timer
        local timeLeft = math.max(math.Truncate(30 - (CurTime() - demonicsheep.SheepStartTime),0) + 1, 0)
        local timerX = x + w * 0.5 - self.timersize * 0.5 - self.pad
        local timerY = y - bh
        self:DrawBg(timerX, timerY, self.timersize + 2 * self.pad, bh, self.healthBarColor)
        draw.AdvancedText(tostring(timeLeft), timerFont, timerX + self.pad + self.timersize * 0.5, timerY + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, false, self.scale)
        --drawing interpolation bar
        self:DrawBg(timerX, timerY, self.pad, bh, self.darkOverlayColor)
        self:DrawBg(timerX + self.timersize + self.pad, timerY, self.pad, bh, self.darkOverlayColor)

        --draw boost bar
        self:DrawBar(rx, ry, bw, bh, self.ammoBarColor, demonicsheep.Boost / demonicsheep.MaxBoost, self.scale)
        draw.AdvancedText("R - Boost", barFont, rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, false, self.scale)

        ry = ry + bh

        --draw minify bar
        local text = demonicsheep.Minified and "Right Click - Magnify" or "Right Click - Minify"
        self:DrawBar(rx, ry, bw, bh, self.extraBarColor, math.min(CurTime() - demonicsheep.LastSizeChange, 5.0) / 5.0, self.scale)
        draw.AdvancedText(text, barFont, rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, false, self.scale)

    end

    function HUDELEMENT:DrawObserverSheep(x, y, w, h, fontColor, demonicsheep)
        local rx, ry = x, y
        local bw, bh = w, self.barheight
        --draw boost bar
        self:DrawBar(rx, ry, bw, bh, self.ammoBarColor, demonicsheep.Boost / demonicsheep.MaxBoost, self.scale)
        draw.AdvancedText("R - Boost", barFont, rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, false, self.scale)

        ry = ry + bh

        --draw minify bar
        self:DrawBar(rx, ry, bw, bh, self.extraBarColor, math.min(CurTime() - demonicsheep.LastTrack, 1) / 1.0, self.scale)
        draw.AdvancedText("Left Click - Track", barFont, rx + bw * 0.5, ry + bh * 0.5, fontColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, false, self.scale)

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

        if demonicsheep:GetClass() == "weapon_ttt_demonicsheep" then
            self:Drawdemonicsheep(x, y, w, h, fontColor, demonicsheep)
        else
            self:DrawObserverSheep(x, y, w, h, fontColor, demonicsheep)
        end

        --drawing the interpolation bar
        self:DrawBg(x, y, self.pad, h, self.darkOverlayColor)

    end
end