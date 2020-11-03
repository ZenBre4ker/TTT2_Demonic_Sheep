-- File copied from TTT2 out of my own Pullrequest
-- Switching to official version if it gets released
-- This works only as placeholder
-- Status: Unreleased, Last Checked Date: 22.10.2020

if SERVER then
    AddCSLuaFile()
    return
end

targetid = targetid or {}

local MAX_TRACE_LENGTH = math.sqrt(3) * 32768

---
-- This function handles finding Entities by casting a ray from a point in a direction, filtering out certain entities
-- Use this in combination with the hook @GM:TTTModifyTargetedEntity to create your own Remote Camera with TargetIDs.
-- e.g. This is used in @GM:HUDDrawTargetID before drawing the TargetIDs. Use that code as example.
-- @note This finds the next Entity, that doesn't get filtered out and can get hit by a bullet, from a position in a direction.
-- @param vector pos Position of Ray Origin.
-- @param vector dir Direction of the Ray. Should be normalized.
-- @param table filter List of all @{Entity}s that should be filtered out.
-- @return entity The Entity that got found
-- @return number The Distance between the Origin and the Entity
-- @realm client
function targetid.FindEntityAlongView(pos, dir, filter)
    local endpos = dir
    endpos:Mul(MAX_TRACE_LENGTH)
    endpos:Add(pos)

    local ent, distance

    -- if the user is looking at a traitor button, it should always be handled with priority
    if TBHUD.focus_but and IsValid(TBHUD.focus_but.ent) and (TBHUD.focus_but.access or TBHUD.focus_but.admin) and TBHUD.focus_stick >= CurTime() then
        ent = TBHUD.focus_but.ent

        distance = pos:Distance(ent:GetPos())
    else
        local trace = util.TraceLine({
            start = pos,
            endpos = endpos,
            mask = MASK_SHOT,
            filter = filter
        })

        -- this is the entity the player is looking at right now
        ent = trace.Entity

        distance = trace.StartPos:Distance(trace.HitPos)

        -- if a vehicle, we identify the driver instead
        if IsValid(ent) and IsValid(ent:GetNWEntity("ttt_driver", nil)) then
            ent = ent:GetNWEntity("ttt_driver", nil)
        end
    end

    return ent, distance
end