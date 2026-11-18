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

/**
 * Returns whether the current mode and lists require this player to run the anti-cheat client.
 * Mode 0 (everyone must use it): true for everyone except the whitelist.
 * Mode 1 (only the required list): true only for the players on the required list.
 * It does not look at anti_cheat_enabled; use L4D2AC_GetStatus for that.
 *
 * @param client	Client index
 * @return			True if the player must run the anti-cheat client
 * @error			Invalid client index
 */
native bool L4D2AC_IsRequired(int client);

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
	MarkNativeAsOptional("L4D2AC_IsRequired");
}
#endif
