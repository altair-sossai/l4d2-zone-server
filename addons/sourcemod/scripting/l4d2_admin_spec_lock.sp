#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <l4d2util_constants>

ConVar g_cvarEnabled;
ConVar g_cvarLockTime;

bool  g_mixActive;
float g_lockUntil[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "L4D2 Admin Spectator Lock",
	author = "Altair Sossai",
	description = "Temporarily prevents players moved to spectators with sm_swapto from rejoining a team",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	LoadTranslations("l4d2_admin_spec_lock.phrases");

	g_cvarEnabled = CreateConVar(
		"l4d2_admin_spec_lock_enabled",
		"0",
		"Enable the temporary team rejoin lock after an admin uses sm_swapto to move a player to spectators",
		FCVAR_NOTIFY,
		true,
		0.0,
		true,
		1.0
	);
	g_cvarLockTime = CreateConVar(
		"l4d2_admin_spec_lock_time",
		"60",
		"Seconds a player moved to spectators with sm_swapto must wait before rejoining a team",
		FCVAR_NOTIFY,
		true,
		0.0
	);

	g_cvarEnabled.AddChangeHook(Cvar_EnabledChanged);
	g_cvarLockTime.AddChangeHook(Cvar_LockTimeChanged);

	AddCommandListener(SwapTo_Listener, "sm_swapto");
	AddCommandListener(JoinTeam_Listener, "jointeam");
}

public void OnMapStart()
{
	g_mixActive = false;
	ClearAllLocks();
}

public void OnClientPutInServer(int client)
{
	g_lockUntil[client] = 0.0;
}

public void OnClientDisconnect(int client)
{
	g_lockUntil[client] = 0.0;
}

/**
 * Global forwards provided by l4d2_mix.sp.
 */
public void OnMixStarted()
{
	g_mixActive = true;
	ClearAllLocks();
}

public void OnMixStopped()
{
	g_mixActive = false;
}

Action SwapTo_Listener(int client, const char[] command, int argc)
{
	if (!g_cvarEnabled.BoolValue || g_mixActive || argc != 2)
	{
		return Plugin_Continue;
	}

	char teamArgument[4];
	GetCmdArg(1, teamArgument, sizeof(teamArgument));
	if (StringToInt(teamArgument) != TEAM_SPECTATOR)
	{
		return Plugin_Continue;
	}

	char targetArgument[MAX_NAME_LENGTH];
	GetCmdArg(2, targetArgument, sizeof(targetArgument));

	int targets[MAXPLAYERS + 1];
	char targetName[MAX_TARGET_LENGTH];
	bool targetNameIsMl;
	int targetCount = ProcessTargetString(
		targetArgument,
		0,
		targets,
		sizeof(targets),
		COMMAND_FILTER_NO_BOTS,
		targetName,
		sizeof(targetName),
		targetNameIsMl
	);

	if (targetCount == 1)
	{
		int target = targets[0];
		if (IsClientInGame(target) && GetClientTeam(target) != TEAM_SPECTATOR)
		{
			RequestFrame(Frame_ApplyLock, GetClientUserId(target));
		}
	}

	return Plugin_Continue;
}

void Frame_ApplyLock(any userId)
{
	if (!g_cvarEnabled.BoolValue || g_mixActive || g_cvarLockTime.FloatValue <= 0.0)
	{
		return;
	}

	int target = GetClientOfUserId(userId);
	if (target > 0 && IsClientInGame(target) && GetClientTeam(target) == TEAM_SPECTATOR)
	{
		g_lockUntil[target] = GetEngineTime() + g_cvarLockTime.FloatValue;
	}
}

Action JoinTeam_Listener(int client, const char[] command, int argc)
{
	if (!g_cvarEnabled.BoolValue || g_mixActive || client < 1 || !IsClientInGame(client)
		|| GetClientTeam(client) != TEAM_SPECTATOR || argc < 1)
	{
		return Plugin_Continue;
	}

	char teamArgument[32];
	GetCmdArg(1, teamArgument, sizeof(teamArgument));
	if (!IsPlayableTeamArgument(teamArgument))
	{
		return Plugin_Continue;
	}

	int secondsRemaining = GetLockSecondsRemaining(client);
	if (secondsRemaining <= 0)
	{
		return Plugin_Continue;
	}

	CPrintToChat(client, "%t %t", "Tag", "LockRemaining", secondsRemaining);
	return Plugin_Handled;
}

bool IsPlayableTeamArgument(const char[] argument)
{
	int team = StringToInt(argument);
	return team == TEAM_SURVIVOR
		|| team == TEAM_ZOMBIE
		|| StrEqual(argument, "Survivor", false)
		|| StrEqual(argument, "Survivors", false)
		|| StrEqual(argument, "Infected", false);
}

int GetLockSecondsRemaining(int client)
{
	float remaining = g_lockUntil[client] - GetEngineTime();
	if (remaining <= 0.0)
	{
		g_lockUntil[client] = 0.0;
		return 0;
	}

	return RoundToCeil(remaining);
}

void ClearAllLocks()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		g_lockUntil[client] = 0.0;
	}
}

void Cvar_EnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!convar.BoolValue)
	{
		ClearAllLocks();
	}
}

void Cvar_LockTimeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar.FloatValue <= 0.0)
	{
		ClearAllLocks();
	}
}
