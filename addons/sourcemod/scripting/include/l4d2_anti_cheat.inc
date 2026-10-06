#if defined _l4d2_anti_cheat_included_
	#endinput
#endif
#define _l4d2_anti_cheat_included_

enum AntiCheatStatus
{
	AntiCheatStatus_Disabled = 0,       // Enforcement is off: the plugin only reports to the API
	AntiCheatStatus_Enabled = 1,        // Enforcement is on: players without a valid client are kept in spectators
	AntiCheatStatus_ApiUnavailable = 2  // Enforcement is on, but the API is unreachable and the plugin is failing open
};

/**
 * Returns the current anti-cheat enforcement status.
 *
 * @return	Current AntiCheatStatus
 */
native AntiCheatStatus L4D2AC_GetStatus();

public SharedPlugin __pl_l4d2_anti_cheat =
{
	name = "l4d2_anti_cheat",
	file = "l4d2-anti-cheat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_anti_cheat_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2AC_GetStatus");
}
#endif
