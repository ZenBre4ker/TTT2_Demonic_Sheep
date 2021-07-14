--make sure that the convarutil.lua exists that adds all convars
if SERVER then
	AddCSLuaFile()
	if file.Exists("terrortown/scripts/sh_convarutil_local.lua", "LUA") then
		AddCSLuaFile("terrortown/scripts/sh_convarutil_local.lua")
	end
end

if file.Exists("terrortown/scripts/sh_convarutil_local.lua", "LUA") then
	include("terrortown/scripts/sh_convarutil_local.lua")
-- Must run before hook.Add
	local shortNameOfAddon = "DemnShp"
	local longNameOfAddon = "Demonic Sheep"

	local cg = ConvarGroup(shortNameOfAddon, longNameOfAddon)

	--Convar(ConvarGroup cg , Bool TTT2-Only, String ttt_Addon_Modifier, Bool/Int/Float DefaultValue, Table{} FCVAR_Flags, String Modifier Description, String Datatype ("bool","int","float"), Bool/Int/Float MinValue, Bool/Int/Float MaxValue, Int Decimalpoints)
	--Example:
	--Convar(cg, false, "ttt_asm_shift_speed_modifier", 2, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Movement speed multiplier during the aiming sequence", "float", 0.01, 8, 2)

	Convar(cg, true, "ttt_DemnShp_ReloadTime", 1.0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Time between two Control-Attacks.", "float", 0.1, 5.0, 1)
	Convar(cg, true, "ttt_DemnShp_EnableAttackControl", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Should the Sheep be able to Control Primary Attacks?", "bool", 0, 1, 0)
	Convar(cg, true, "ttt_DemnShp_AttackControlDuration", 0.5, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "How long the duration of the Attack Control should be?", "float", 0.1, 5.0, 1)
	Convar(cg, true, "ttt_DemnShp_EnableDropControl", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Should the Sheep be able to drop Enemy Weapons?", "bool", 0, 1, 0)
	Convar(cg, true, "ttt_DemnShp_EnableHolsterControl", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Should the Sheep be able to holster Enemy Weapons?", "bool", 0, 1, 0)
	Convar(cg, true, "ttt_DemnShp_EnableMovementControl", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Should the Sheep be able to Control Enemy Movement?", "bool", 0, 1, 0)
	Convar(cg, true, "ttt_DemnShp_MovementControlDuration", 1.0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "How long the duration of the Movement Control should be?", "float", 0.5, 5.0, 1)
--

print(longNameOfAddon .. " Convars are created.")

end
