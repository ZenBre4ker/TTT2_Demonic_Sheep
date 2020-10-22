--[[ Spectator labels
local function DrawPropSpecLabels(client)
	if not client:IsSpec() and GetRoundState() ~= ROUND_POST then return end

	surface.SetFont("TabLarge")

	local tgt, scrpos, text
	local w = 0
	local plys = player.GetAll()

	for i = 1, #plys do
		local ply = plys[i]

		if ply:IsSpec() then
			surface.SetTextColor(220, 200, 0, 120)

			tgt = ply:GetObserverTarget()

			if IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == ply then
				scrpos = tgt:GetPos():ToScreen()
			else
				scrpos = nil
			end
		else
			local _, healthcolor = util.HealthToString(ply:Health(), ply:GetMaxHealth())

			surface.SetTextColor(clr(healthcolor))

			scrpos = ply:EyePos()
			scrpos.z = scrpos.z + 20
			scrpos = scrpos:ToScreen()
		end

		if scrpos == nil or IsOffScreen(scrpos) then continue end

		text = ply:Nick()
		w = surface.GetTextSize(text)

		surface.SetTextPos(scrpos.x - w * 0.5, scrpos.y)
		surface.DrawText(text)
	end
end

function hudtargetidimpl_ttt2Simple(ent, distance)
	local client = LocalPlayer()
	local demonicsheep = client:GetActiveWeapon().Ent_demonicsheep
	if IsValid(demonicsheep) then
		local startpos = Vector(0,0,0)
		local viewAngle = client:EyeAngles()
		startpos, viewAngle = demonicsheep_View(client:GetActiveWeapon(),startpos,viewAngle)
		local endpos = client:GetAimVector()

		local MAX_TRACE_LENGTH = math.sqrt(3) * 32768
		endpos:Mul(MAX_TRACE_LENGTH)
		endpos:Add(startpos)

		-- if the user is looking at a traitor button, it should always be handled with priority
		if TBHUD.focus_but and IsValid(TBHUD.focus_but.ent) and (TBHUD.focus_but.access or TBHUD.focus_but.admin) and TBHUD.focus_stick >= CurTime() then
			ent = TBHUD.focus_but.ent

			distance = startpos:Distance(ent:GetPos())
		else
			local trace = util.TraceLine({
				start = startpos,
				endpos = endpos,
				mask = MASK_SHOT,
				filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()} or client
			})

			-- this is the entity the player is looking at right now
			ent = trace.Entity

			distance = trace.StartPos:Distance(trace.HitPos)
		end
		
		-- if a vehicle, we identify the driver instead
		if IsValid(ent) and IsValid(ent:GetNWEntity("ttt_driver", nil)) then
			ent = ent:GetNWEntity("ttt_driver", nil)
		end

	end
	return ent
end

function hudtargetidimpl_ttt2fixed()
	--print("\n------------TTT2Fixed HudDrawTargetID-----------\n")
	local client = LocalPlayer()
	--local demonicsheep = client:GetNWEntity("demonicsheep_entity")
	local demonicsheep = client:GetActiveWeapon().Ent_demonicsheep
	if IsValid(demonicsheep) then
	--print("DemonicSheep is Valid.")

		if hook.Call("HUDShouldDraw", GAMEMODE, "TTTPropSpec") then
			DrawPropSpecLabels(client)
		end

		--local startpos = client:EyePos()
		local startpos = Vector(0,0,0)
		local viewAngle = client:EyeAngles()
		startpos, viewAngle = demonicsheep_View(client:GetActiveWeapon(),startpos,viewAngle)
		local endpos = client:GetAimVector()

		local MAX_TRACE_LENGTH = math.sqrt(3) * 32768
		endpos:Mul(MAX_TRACE_LENGTH)
		endpos:Add(startpos)

		local ent, unchangedEnt, distance

		-- if the user is looking at a traitor button, it should always be handled with priority
		if TBHUD.focus_but and IsValid(TBHUD.focus_but.ent) and (TBHUD.focus_but.access or TBHUD.focus_but.admin) and TBHUD.focus_stick >= CurTime() then
			ent = TBHUD.focus_but.ent

			distance = startpos:Distance(ent:GetPos())
		else
			local trace = util.TraceLine({
				start = startpos,
				endpos = endpos,
				mask = MASK_SHOT,
				filter = IsValid(demonicsheep) or (client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()} or client)
			})

			-- this is the entity the player is looking at right now
			ent = trace.Entity

			distance = trace.StartPos:Distance(trace.HitPos)
		end

		-- if a vehicle, we identify the driver instead
		if IsValid(ent) and IsValid(ent:GetNWEntity("ttt_driver", nil)) then
			ent = ent:GetNWEntity("ttt_driver", nil)
		end

		-- only add onscreen infos when the entity isn't the local player
		--if ent == client then return end

		local changedEnt = hook.Run("TTTModifyTargetedEntity", ent, distance)

		if changedEnt then
			unchangedEnt = ent
			ent = changedEnt
		end

		-- make sure it is a valid entity
		if not IsValid(ent) or ent.NoTarget then 
			--print("\n------------TTT HUD HOOK RETURN AT VALID ENTITY------------\n")
			return 
		end

		-- combine data into a table to read them inside a hook
		local data = {
			ent = ent,
			unchangedEnt = unchangedEnt,
			distance = distance
		}

		-- preset a table of values that can be changed with a hook
		local params = {
			drawInfo = nil,
			drawOutline = nil,
			outlineColor = COLOR_WHITE,
			displayInfo = {
				key = nil,
				icon = {},
				title = {
					icons = {},
					text = "",
					color = COLOR_WHITE
				},
				subtitle = {
					icons = {},
					text = "",
					color = COLOR_LLGRAY
				},
				desc = {}
			},
			refPosition = {
				x = math.Round(0.5 * ScrW(), 0),
				y = math.Round(0.5 * ScrH(), 0) + 42
			}
		}

		-- call internal targetID functions first so the data can be modified by addons
		local tData = TARGET_DATA:BindTarget(data, params)

		HUDDrawTargetIDTButtons(tData)
		HUDDrawTargetIDWeapons(tData)
		HUDDrawTargetIDPlayers(tData)
		HUDDrawTargetIDRagdolls(tData)
		HUDDrawTargetIDDoors(tData)
		HUDDrawTargetIDDNAScanner(tData)

		-- now run a hook that can be used by addon devs that changes the appearance
		-- of the targetid
		hook.Run("TTTRenderEntityInfo", tData)

		if ent == client then
			params.drawOutline = true
			params.outlineColor = COLOR_GREEN
		end

		local cv_draw_halo = GetConVar("ttt_entity_draw_halo")

		-- draws an outline around the entity if defined
		if params.drawOutline and cv_draw_halo:GetBool() then
			outline.Add(
				data.ent,
				params.outlineColor,
				OUTLINE_MODE_VISIBLE
			)
		end
		
		if not params.drawInfo then 
			--print("\n------------TTT HUD HOOK RETURN AT DRAWINFO------------\n")	
			return 
		end

		-- render on display text
		local pad = 4
		local pad2 = pad * 2

		-- draw key and keybox
		-- the keyboxsize gets used as reference value since in most cases a key will be rendered
		-- therefore the key size gets calculated every time, even if no key is set
		local key_string = string.upper(params.displayInfo.key and input.GetKeyName(params.displayInfo.key) or "")

		local key_string_w, key_string_h = draw.GetTextSize(key_string, "TargetID_Key")

		local key_box_w = key_string_w + 5 * pad
		local key_box_h = key_string_h + pad2
		local key_box_x = params.refPosition.x - key_box_w - pad2 - 2 -- -2 because of border width
		local key_box_y = params.refPosition.y

		local key_string_x = key_box_x + math.Round(0.5 * key_box_w) - 1
		local key_string_y = key_box_y + math.Round(0.5 * key_box_h) - 1

		if params.displayInfo.key then
			draw.Box(key_box_x, key_box_y, key_box_w, key_box_h, colorKeyBack)

			draw.OutlinedShadowedBox(key_box_x, key_box_y, key_box_w, key_box_h, 1, COLOR_WHITE)
			draw.ShadowedText(key_string, "TargetID_Key", key_string_x, key_string_y, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		-- draw icon
		local icon_amount = #params.displayInfo.icon
		local icon_x, icon_y

		if icon_amount > 0 then
			icon_x = params.refPosition.x - key_box_h - pad2
			icon_y = params.displayInfo.key and (key_box_y + key_box_h + pad2) or key_box_y + 1

			for i = 1, icon_amount do
				local icon = params.displayInfo.icon[i]
				local color = icon.color or COLOR_WHITE

				draw.FilteredShadowedTexture(icon_x, icon_y, key_box_h, key_box_h, icon.material, color.a, color)

				icon_y = icon_y + key_box_h
			end
		end

		-- draw title
		local title_string = params.displayInfo.title.text or ""

		local _, title_string_h = draw.GetTextSize(title_string, "TargetID_Title")

		local title_string_x = params.refPosition.x + pad2
		local title_string_y = key_box_y + title_string_h - 4

		for i = 1, #params.displayInfo.title.icons do
			draw.FilteredShadowedTexture(title_string_x, title_string_y - 16, 14, 14, params.displayInfo.title.icons[i], params.displayInfo.title.color.a, params.displayInfo.title.color)

			title_string_x = title_string_x + 18
		end

		draw.ShadowedText(title_string, "TargetID_Title", title_string_x, title_string_y, params.displayInfo.title.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		-- draw subtitle
		local subtitle_string = params.displayInfo.subtitle.text or ""

		local subtitle_string_x = params.refPosition.x + pad2
		local subtitle_string_y = key_box_y + key_box_h + 2

		for i = 1, #params.displayInfo.subtitle.icons do
			draw.FilteredShadowedTexture(subtitle_string_x, subtitle_string_y - 14, 12, 12, params.displayInfo.subtitle.icons[i], params.displayInfo.subtitle.color.a, params.displayInfo.subtitle.color)

			subtitle_string_x = subtitle_string_x + 16
		end

		draw.ShadowedText(subtitle_string, "TargetID_Subtitle", subtitle_string_x, subtitle_string_y, params.displayInfo.subtitle.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

		-- in cvMinimalisticTid mode, no descriptions should be shown
		local desc_line_amount, desc_line_h = 0, 0
		local minimalist = GetConVar("ttt_minimal_targetid")

		if not minimalist:GetBool() then
			-- draw description text
			local desc_lines = params.displayInfo.desc

			local desc_string_x = params.refPosition.x + pad2
			local desc_string_y = key_box_y + key_box_h + 8 * pad
			desc_line_h = 17
			desc_line_amount = #desc_lines

			for i = 1, desc_line_amount do
				local text = desc_lines[i].text
				local icons = desc_lines[i].icons
				local color = desc_lines[i].color
				local desc_string_x_loop = desc_string_x

				for j = 1, #icons do
					draw.FilteredShadowedTexture(desc_string_x_loop, desc_string_y - 13, 11, 11, icons[j], color.a, color)

					desc_string_x_loop = desc_string_x_loop + 14
				end

				draw.ShadowedText(text, "TargetID_Description", desc_string_x_loop, desc_string_y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
				desc_string_y = desc_string_y + desc_line_h
			end
		end

		-- draw spacer line
		local spacer_line_x = params.refPosition.x - 1
		local spacer_line_y = key_box_y

		local spacer_line_icon_l = (icon_y and icon_y or spacer_line_y) - spacer_line_y
		local spacer_line_text_l = key_box_h + ((desc_line_amount > 0) and (4 * pad + desc_line_h * desc_line_amount - 3) or 0)

		local spacer_line_l = (spacer_line_icon_l > spacer_line_text_l) and spacer_line_icon_l or spacer_line_text_l

		draw.ShadowedLine(spacer_line_x, spacer_line_y, spacer_line_x, spacer_line_y + spacer_line_l, COLOR_WHITE)
		
		--print("\n------------TTT HUD HOOK RETURN AT THE END------------\n")
		return
		
	else
	--print("DemonicSheep is not Valid.")
	end
end

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
--]]