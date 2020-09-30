
function hudtargetidimpl_default()
   if IsValid(LocalPlayer()) && IsValid(LocalPlayer():GetActiveWeapon()) && not LocalPlayer():GetNWBool("demonicsheep_removed") && IsValid(LocalPlayer():GetNWEntity("demonicsheep_entity")) then
	   --print("test")
	   
	   local GetRaw = LANG.GetRawTranslation
	   local GetPTranslation = LANG.GetParamTranslation
	   
	   local key_params = {usekey = Key("+use", "USE"), walkkey = Key("+walk", "WALK")}
	   
	   local ClassHint = {
	   prop_ragdoll = {
		  name= "corpse",
		  hint= "corpse_hint",

		  fmt = function(ent, txt) return GetPTranslation(txt, key_params) end
		   }
		};

		local minimalist = CreateConVar("ttt_minimal_targetid", "0", FCVAR_ARCHIVE)

		local magnifier_mat = Material("icon16/magnifier.png")
		local ring_tex = surface.GetTextureID("effects/select_ring")

		local rag_color = Color(200,200,200,255)

	   
	   local MAX_TRACE_LENGTH = math.sqrt(3) * 2 * 16384
	   local GetLang = LANG.GetUnsafeLanguageTable
	   
	   local client = LocalPlayer()

	   local L = GetLang()

	   -- if hook.Call( "HUDShouldDraw", GAMEMODE, "TTTPropSpec" ) then
		  -- DrawPropSpecLabels(client)
	   -- end
		
	   local demonicsheep = LocalPlayer():GetNWEntity("demonicsheep_entity")
		
	   local startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*100 + Vector(0, 0, -45))
	   
	   local endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -45))
	   if LocalPlayer():GetNWBool("demonicsheep_small") then
			startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*50 + Vector(0, 0, -10))
			endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -10))
	   end
	   --endpos:Mul(MAX_TRACE_LENGTH)
	   --endpos:Add(startpos)

	   local trace = util.TraceLine({
		  start = startpos,
		  endpos = endpos,
		  mask = MASK_SHOT,
		  filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()}
	   })
	   local ent = trace.Entity
	   if (not IsValid(ent)) or ent.NoTarget then return false end

	   -- some bools for caching what kind of ent we are looking at
	   local target_traitor = false
	   local target_detective = false
	   local target_corpse = false

	   local text = nil
	   local color = COLOR_WHITE

	   -- if a vehicle, we identify the driver instead
	   if IsValid(ent:GetNWEntity("ttt_driver", nil)) then
		  ent = ent:GetNWEntity("ttt_driver", nil)

		  if ent == client then return false end
	   end

	   local cls = ent:GetClass()
	   local minimal = minimalist:GetBool()
	   local hint = (not minimal) and (ent.TargetIDHint or ClassHint[cls])

	   if ent:IsPlayer() then
		  if ent:GetNWBool("disguised", false) then
			 client.last_id = nil

			 if client:IsTraitor() or client:IsSpec() then
				text = ent:Nick() .. L.target_disg
			 else
				-- Do not show anything
				return false
			 end

			 color = COLOR_RED
		  else
			 text = ent:Nick()
			 client.last_id = ent
		  end

		  local _ -- Stop global clutter
		  -- in minimalist targetID, colour nick with health level
		  if minimal then
			 _, color = util.HealthToString(ent:Health(), ent:GetMaxHealth())
		  end

		  if client:IsTraitor() and GetRoundState() == ROUND_ACTIVE then
			 target_traitor = ent:IsTraitor()
		  end

		  target_detective = GetRoundState() > ROUND_PREP and ent:IsDetective() or false

	   elseif cls == "prop_ragdoll" then
		  -- only show this if the ragdoll has a nick, else it could be a mattress
		  if CORPSE.GetPlayerNick(ent, false) == false then return false end

		  target_corpse = true

		  if CORPSE.GetFound(ent, false) or not DetectiveMode() then
			 text = CORPSE.GetPlayerNick(ent, "A Terrorist")
		  else
			 text  = L.target_unid
			 color = COLOR_YELLOW
		  end
	   elseif not hint then
		  -- Not something to ID and not something to hint about
		  return false
	   end

	   local x_orig = ScrW() / 2.0
	   local x = x_orig
	   local y = ScrH() / 2.0

	   local w, h = 0,0 -- text width/height, reused several times

	   if target_traitor or target_detective then
		  surface.SetTexture(ring_tex)

		  if target_traitor then
			 surface.SetDrawColor(255, 0, 0, 200)
		  else
			 surface.SetDrawColor(0, 0, 255, 220)
		  end
		  surface.DrawTexturedRect(x-32, y-32, 64, 64)
	   end

	   y = y + 30
	   local font = "TargetID"
	   surface.SetFont( font )

	   -- Draw main title, ie. nickname
	   if text then
		  w, h = surface.GetTextSize( text )

		  x = x - w / 2

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, color )

		  -- for ragdolls searched by detectives, add icon
		  if ent.search_result and client:IsDetective() then
			 -- if I am detective and I know a search result for this corpse, then I
			 -- have searched it or another detective has
			 surface.SetMaterial(magnifier_mat)
			 surface.SetDrawColor(200, 200, 255, 255)
			 surface.DrawTexturedRect(x + w + 5, y, 16, 16)
		  end

		  y = y + h + 4
	   end

	   -- Minimalist target ID only draws a health-coloured nickname, no hints, no
	   -- karma, no tag
	   if minimal then return false end

	   -- Draw subtitle: health or type
	   local clr = rag_color
	   if ent:IsPlayer() then
		  text, clr = util.HealthToString(ent:Health(), ent:GetMaxHealth())

		  -- HealthToString returns a string id, need to look it up
		  text = L[text]
	   elseif hint then
		  text = GetRaw(hint.name) or hint.name
	   else
		  return false
	   end
	   font = "TargetIDSmall2"

	   surface.SetFont( font )
	   w, h = surface.GetTextSize( text )
	   x = x_orig - w / 2

	   draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
	   draw.SimpleText( text, font, x, y, clr )

	   font = "TargetIDSmall"
	   surface.SetFont( font )

	   -- Draw second subtitle: karma
	   if ent:IsPlayer() and KARMA.IsEnabled() then
		  text, clr = util.KarmaToString(ent:GetBaseKarma())

		  text = L[text]

		  w, h = surface.GetTextSize( text )
		  y = y + h + 5
		  x = x_orig - w / 2

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, clr )
	   end

	   -- Draw key hint
	   if hint and hint.hint then
		  if not hint.fmt then
			 text = GetRaw(hint.hint) or hint.hint
		  else
			 text = hint.fmt(ent, hint.hint)
		  end

		  w, h = surface.GetTextSize(text)
		  x = x_orig - w / 2
		  y = y + h + 5
		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, COLOR_LGRAY )
	   end

	   text = nil

	   if target_traitor then
		  text = L.target_traitor
		  clr = COLOR_RED
	   elseif target_detective then
		  text = L.target_detective
		  clr = COLOR_BLUE
	   elseif ent.sb_tag and ent.sb_tag.txt != nil then
		  text = L[ ent.sb_tag.txt ]
		  clr = ent.sb_tag.color
	   elseif target_corpse and client:IsActiveTraitor() and CORPSE.GetCredits(ent, 0) > 0 then
		  text = L.target_credits
		  clr = COLOR_YELLOW
	   end

	   if text then
		  w, h = surface.GetTextSize( text )
		  x = x_orig - w / 2
		  y = y + h + 5

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, clr )
	   end
	   return false
	end
end

function hudtargetidimpl_totem()
	 if IsValid(LocalPlayer()) && IsValid(LocalPlayer():GetActiveWeapon()) && not LocalPlayer():GetNWBool("demonicsheep_removed") && IsValid(LocalPlayer():GetNWEntity("demonicsheep_entity")) then
	   
	   local GetRaw = LANG.GetRawTranslation
	   local GetPTranslation = LANG.GetParamTranslation
	   
	   local key_params = {usekey = Key("+use", "USE"), walkkey = Key("+walk", "WALK")}
	   
	   local ClassHint = {
	   prop_ragdoll = {
		  name= "corpse",
		  hint= "corpse_hint",

		  fmt = function(ent, txt) return GetPTranslation(txt, key_params) end
		   }
		};

		local minimalist = CreateConVar("ttt_minimal_targetid", "0", FCVAR_ARCHIVE)

		local magnifier_mat = Material("icon16/magnifier.png")
		local ring_tex = surface.GetTextureID("effects/select_ring")

		local rag_color = Color(200,200,200,255)

	   
	   local MAX_TRACE_LENGTH = math.sqrt(3) * 2 * 16384
	   local GetLang = LANG.GetUnsafeLanguageTable
   
	   local client = LocalPlayer()

	   local L = GetLang()

	   -- if hook.Call( "HUDShouldDraw", GAMEMODE, "TTTPropSpec" ) then
		  -- DrawPropSpecLabels(client)
	   -- end
	   
	   local demonicsheep = LocalPlayer():GetNWEntity("demonicsheep_entity")
		
	   local startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*100 + Vector(0, 0, -45)) 
	   local endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -45))
	   	   if LocalPlayer():GetNWBool("demonicsheep_small") then
			startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*50 + Vector(0, 0, -10))
			endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -10))
	   end  
	   --endpos:Mul(MAX_TRACE_LENGTH)
	  -- endpos:Add(startpos)

	   local trace = util.TraceLine({
		  start = startpos,
		  endpos = endpos,
		  mask = MASK_SHOT,
		  filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()}
	   })
	   local ent = trace.Entity
	   if (not IsValid(ent)) or ent.NoTarget then return false end

	   -- some bools for caching what kind of ent we are looking at
	   local target = {}
	   target.traitor = false
	   target.detective = false
	   target.corpse = false

	   local text = nil
	   local color = COLOR_WHITE

	   -- if a vehicle, we identify the driver instead
	   if IsValid(ent:GetNWEntity("ttt_driver", nil)) then
		  ent = ent:GetNWEntity("ttt_driver", nil)

		  if ent == client then return false end
	   end

	   local cls = ent:GetClass()
	   local minimal = minimalist:GetBool()
	   local hint = (not minimal) and (ent.TargetIDHint or ClassHint[cls])
	   local roletbl = ent:IsPlayer() and ent:GetRoleTable()

	   if ent:IsPlayer() then
		  if ent:GetNWBool("disguised", false) then
			 client.last_id = nil

			 if client:IsEvil() or client:IsSpec() then
				text = ent:Nick() .. L.target_disg
			 else
				-- Do not show anything
				return false
			 end

			 color = COLOR_RED
		  else
			 text = ent:Nick()
			 client.last_id = ent
		  end

		  local _ -- Stop global clutter
		  -- in minimalist targetID, colour nick with health level
		  if minimal then
			 _, color = util.HealthToString(ent:Health(), ent:GetMaxHealth())
		  end

		  if client:IsEvil() and GetRoundState() == ROUND_ACTIVE then
			 target.traitor = ent:IsTraitor()
		  end


		  if roletbl.drawtargetidcircle and ent:GetTeam() == client:GetTeam()  then
			 target[roletbl.String] = true
		  end


		  target.detective = GetRoundState() > ROUND_PREP and ent:IsDetective() or false

	   elseif cls == "prop_ragdoll" then
		  -- only show this if the ragdoll has a nick, else it could be a mattress
		  if CORPSE.GetPlayerNick(ent, false) == false then return false end

		  target.corpse = true

		  if CORPSE.GetFound(ent, false) or not DetectiveMode() then
			 text = CORPSE.GetPlayerNick(ent, "A Terrorist")
		  else
			 text  = L.target_unid
			 color = COLOR_YELLOW
		  end
	   elseif not hint then
		  -- Not something to ID and not something to hint about
		  return false
	   end

	   local x_orig = ScrW() / 2.0
	   local x = x_orig
	   local y = ScrH() / 2.0

	   local w, h = 0,0 -- text width/height, reused several times

	   if ent:IsPlayer() then
		  for k,v in pairs(target) do
			 if v and roletbl.drawtargetidcircle then
				surface.SetTexture(ring_tex)
				local col = roletbl.DefaultColor
				surface.SetDrawColor(Color(col.r,col.g,col.b,200))
				surface.DrawTexturedRect(x-32, y-32, 64, 64)
			 end
		  end
	   end

	   y = y + 30
	   local font = "TargetID"
	   surface.SetFont( font )

	   -- Draw main title, ie. nickname
	   if text then
		  w, h = surface.GetTextSize( text )

		  x = x - w / 2

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, color )

		  -- for ragdolls searched by detectives, add icon
		  if ent.search_result and client:IsDetective() then
			 -- if I am detective and I know a search result for this corpse, then I
			 -- have searched it or another detective has
			 surface.SetMaterial(magnifier_mat)
			 surface.SetDrawColor(200, 200, 255, 255)
			 surface.DrawTexturedRect(x + w + 5, y, 16, 16)
		  end

		  y = y + h + 4
	   end

	   -- Minimalist target ID only draws a health-coloured nickname, no hints, no
	   -- karma, no tag
	   if minimal then return false end

	   -- Draw subtitle: health or type
	   local clr = rag_color
	   if ent:IsPlayer() then
		  text, clr = util.HealthToString(ent:Health(), ent:GetMaxHealth())

		  -- HealthToString returns a string id, need to look it up
		  text = L[text]
	   elseif hint then
		  text = GetRaw(hint.name) or hint.name
	   else
		  return false
	   end
	   font = "TargetIDSmall2"

	   surface.SetFont( font )
	   w, h = surface.GetTextSize( text )
	   x = x_orig - w / 2

	   draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
	   draw.SimpleText( text, font, x, y, clr )

	   font = "TargetIDSmall"
	   surface.SetFont( font )

	   -- Draw second subtitle: karma
	   if ent:IsPlayer() and KARMA.IsEnabled() then
		  text, clr = util.KarmaToString(ent:GetBaseKarma())

		  text = L[text]

		  w, h = surface.GetTextSize( text )
		  y = y + h + 5
		  x = x_orig - w / 2

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, clr )
	   end

	   -- Draw key hint
	   if hint and hint.hint then
		  if not hint.fmt then
			 text = GetRaw(hint.hint) or hint.hint
		  else
			 text = hint.fmt(ent, hint.hint)
		  end

		  w, h = surface.GetTextSize(text)
		  x = x_orig - w / 2
		  y = y + h + 5
		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, COLOR_LGRAY )
	   end

	   text = nil

	   if ent:IsPlayer() then
		  for k,v in pairs(target) do
			 if v and k != "corpse" then
				text = L["target_" .. roletbl.String]
				clr = roletbl.DefaultColor
			 end
		  end
	   end

	   if ent.sb_tag and ent.sb_tag.txt != nil then
		  text = L[ ent.sb_tag.txt ]
		  clr = ent.sb_tag.color
	   elseif target.corpse and client:IsActiveEvil() and CORPSE.GetCredits(ent, 0) > 0 then
		  text = L.target_credits
		  clr = COLOR_YELLOW
	   end

	   if text then
		  w, h = surface.GetTextSize( text )
		  x = x_orig - w / 2
		  y = y + h + 5

		  draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
		  draw.SimpleText( text, font, x, y, clr )
	   end
	   return false
	end
end

function hudtargetidimpl_ttt2()
    if IsValid(LocalPlayer()) && IsValid(LocalPlayer():GetActiveWeapon()) && not LocalPlayer():GetNWBool("demonicsheep_removed") && IsValid(LocalPlayer():GetNWEntity("demonicsheep_entity")) then
	   
	   local GetRaw = LANG.GetRawTranslation
	   local GetPTranslation = LANG.GetParamTranslation
	   
	   local key_params = {usekey = Key("+use", "USE"), walkkey = Key("+walk", "WALK")}
	   
	   local ClassHint = {
	   prop_ragdoll = {
		  name= "corpse",
		  hint= "corpse_hint",

		  fmt = function(ent, txt) return GetPTranslation(txt, key_params) end
		   }
		};

		local minimalist = CreateConVar("ttt_minimal_targetid", "0", FCVAR_ARCHIVE)

		local magnifier_mat = Material("icon16/magnifier.png")
		local ring_tex = surface.GetTextureID("effects/select_ring")

		local rag_color = Color(200,200,200,255)

	   
	   local MAX_TRACE_LENGTH = math.sqrt(3) * 2 * 16384
	   local GetLang = LANG.GetUnsafeLanguageTable
   
	   local client = LocalPlayer()

	   local L = GetLang()

	   -- if hook.Call( "HUDShouldDraw", GAMEMODE, "TTTPropSpec" ) then
		  -- DrawPropSpecLabels(client)
	   -- end
	   
	   local demonicsheep = LocalPlayer():GetNWEntity("demonicsheep_entity")
		
	   local startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*100 + Vector(0, 0, -45))
	   local endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -45))
	   if LocalPlayer():GetNWBool("demonicsheep_small") then
			startpos = demonicsheep:GetPos() -( LocalPlayer():EyeAngles():Forward()*50 + Vector(0, 0, -10))
			endpos = demonicsheep:GetPos() + ( LocalPlayer():EyeAngles():Forward()*20000 + Vector(0, 0, -10))
	   end
	   
	  
	   local trace = util.TraceLine({
				start = startpos,
				endpos = endpos,
				mask = MASK_SHOT,
				filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()}
		})

		local ent = trace.Entity

		if not IsValid(ent) or ent.NoTarget then return false end

		-- some bools for caching what kind of ent we are looking at
		local target_role
		local target_corpse = false
		local text = nil
		local color = COLOR_WHITE

		-- if a vehicle, we identify the driver instead
		if IsValid(ent:GetNWEntity("ttt_driver", nil)) then
			ent = ent:GetNWEntity("ttt_driver", nil)

			if ent == client then return false end
		end

		local cls = ent:GetClass()
		local minimal = minimalist:GetBool()
		local hint = not minimal and (ent.TargetIDHint or ClassHint[cls])

		if ent:IsPlayer() then
			local obsTgt = client:GetObserverTarget()

			if client:IsSpec() and IsValid(obsTgt) and ent == obsTgt then
				return false
			elseif ent:GetNWBool("disguised", false) then
				client.last_id = nil

				if client:IsInTeam(ent) and not client:GetSubRoleData().unknownTeam or client:IsSpec() then
					text = ent:Nick() .. L.target_disg
				else
					-- Do not show anything
					return false
				end

				color = COLOR_RED
			else
				text = ent:Nick()
				client.last_id = ent
			end

			local _ -- Stop global clutter

			-- in minimalist targetID, colour nick with health level
			if minimal then
				_, color = util.HealthToString(ent:Health(), ent:GetMaxHealth())
			end

			local rstate = GetRoundState()

			if ent.GetSubRole and (rstate > ROUND_PREP and ent:IsDetective() or rstate == ROUND_ACTIVE and ent:IsSpecial()) then
				target_role = ent:GetSubRole()
			end
		elseif cls == "prop_ragdoll" then
			-- only show this if the ragdoll has a nick, else it could be a mattress
			if not CORPSE.GetPlayerNick(ent, false) then return false end

			target_corpse = true

			if CORPSE.GetFound(ent, false) or not DetectiveMode() then
				text = CORPSE.GetPlayerNick(ent, "A Terrorist")
			else
				text = L.target_unid
				color = COLOR_YELLOW
			end
		elseif not hint then
			-- Not something to ID and not something to hint about
			return false
		end

		local x_orig = ScrW() * 0.5
		local x = x_orig
		local y = ScrH() * 0.5
		local w, h = 0, 0 -- text width/height, reused several times

		if target_role then
			surface.SetTexture(ring_tex)

			local c = GetRoleByIndex(target_role).color

			surface.SetDrawColor(c.r, c.g, c.b, 200)
			surface.DrawTexturedRect(x - 32, y - 32, 64, 64)
		end

		y = y + 30

		local font = "TargetID"

		surface.SetFont(font)

		-- Draw main title, ie. nickname
		if text then
			w, h = surface.GetTextSize(text)
			x = x - w * 0.5

			draw.SimpleText(text, font, x + 1, y + 1, COLOR_BLACK)
			draw.SimpleText(text, font, x, y, color)

			-- for ragdolls searched by detectives, add icon
			if ent.search_result and client:IsDetective() then

				-- if I am detective and I know a search result for this corpse, then I
				-- have searched it or another detective has
				surface.SetMaterial(magnifier_mat)
				surface.SetDrawColor(200, 200, 255, 255)
				surface.DrawTexturedRect(x + w + 5, y, 16, 16)
			end

			y = y + h + 4
		end

		-- Minimalist target ID only draws a health-coloured nickname, no hints, no
		-- karma, no tag
		if minimal then return false end

		-- Draw subtitle: health or type
		local c = rag_color

		if ent:IsPlayer() then
			text, c = util.HealthToString(ent:Health(), ent:GetMaxHealth())

			-- HealthToString returns a string id, need to look it up
			text = L[text]
		elseif hint then
			text = GetRaw(hint.name) or hint.name
		else
			return false
		end

		font = "TargetIDSmall2"

		surface.SetFont(font)

		w, h = surface.GetTextSize(text)
		x = x_orig - w * 0.5

		draw.SimpleText(text, font, x + 1, y + 1, COLOR_BLACK)
		draw.SimpleText(text, font, x, y, c)

		font = "TargetIDSmall"
		surface.SetFont(font)

		-- Draw second subtitle: karma
		if ent:IsPlayer() and KARMA.IsEnabled() then
			text, c = util.KarmaToString(ent:GetBaseKarma())

			text = L[text]

			w, h = surface.GetTextSize(text)
			y = y + h + 5
			x = x_orig - w * 0.5

			draw.SimpleText(text, font, x + 1, y + 1, COLOR_BLACK)
			draw.SimpleText(text, font, x, y, c)
		end

		-- Draw key hint
		if hint and hint.hint then
			if not hint.fmt then
				text = GetRaw(hint.hint) or hint.hint
			else
				text = hint.fmt(ent, hint.hint)
			end

			w, h = surface.GetTextSize(text)
			x = x_orig - w * 0.5
			y = y + h + 5

			draw.SimpleText(text, font, x + 1, y + 1, COLOR_BLACK)
			draw.SimpleText(text, font, x, y, COLOR_LGRAY)
		end

		text = nil

		if target_role then
			local rd = GetRoleByIndex(target_role)

			text = L["target_" .. rd.name]
			c = rd.color
		end

		if ent.sb_tag and ent.sb_tag.txt then
			text = L[ent.sb_tag.txt]
			c = ent.sb_tag.color
		elseif target_corpse and client:IsActive() and client:IsShopper() and CORPSE.GetCredits(ent, 0) > 0 then
			text = L.target_credits
			c = COLOR_YELLOW
		end

		if text then
			w, h = surface.GetTextSize(text)
			x = x_orig - w * 0.5
			y = y + h + 5

			draw.SimpleText(text, font, x + 1, y + 1, COLOR_BLACK)
			draw.SimpleText(text, font, x, y, c)
		end
	end
end

