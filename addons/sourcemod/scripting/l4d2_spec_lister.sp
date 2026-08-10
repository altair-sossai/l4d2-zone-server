#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util_constants>
#include <l4d2util_rounds>

#define HEAR_HINT_DELAY 15.0

enum HearMode
{
	Hear_Survivors = 0,
	Hear_Infected,
	Hear_Spectators,
	Hear_All
}

HearMode g_HearMode[MAXPLAYERS + 1];
bool g_Broadcasting[MAXPLAYERS + 1];
ConVar g_AllTalk;

public Plugin myinfo =
{
	name = "L4D2 - Spec Lister",
	author = "Altair Sossai",
	description = "Lets spectators choose which playing team they hear (survivors, infected or both); other spectators are always heard",
	version = "2.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	LoadTranslations("l4d2_spec_lister.phrases");

	RegConsoleCmd("sm_hear", HearCmd, "Choose which players you hear as a spectator (no arg opens the menu; optional arg: survivors/infected/spectators/all)");
	RegAdminCmd("sm_broadcast", BroadcastCmd, ADMFLAG_CHAT, "Toggle broadcast mode: while enabled, everyone hears you");

	HookEvent("player_team", RefreshEvent);

	g_AllTalk = FindConVar("sv_alltalk");

	if (g_AllTalk != null)
		g_AllTalk.AddChangeHook(RefreshConVar);

	for (int client = 1; client <= MaxClients; client++)
		g_HearMode[client] = Hear_All;

	RefreshAllSpectators();
}

public void OnClientPutInServer(int client)
{
	g_HearMode[client] = Hear_All;
	g_Broadcasting[client] = false;

	RefreshAllSpectators();
}

public void OnClientDisconnect(int client)
{
	if (!g_Broadcasting[client])
		return;

	g_Broadcasting[client] = false;

	RefreshAllSpectators();
}

public void OnMapStart()
{
	CreateTimer(HEAR_HINT_DELAY, ShowHearHint_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action ShowHearHint_Timer(Handle timer)
{
	if (InSecondHalfOfRound())
		return Plugin_Continue;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR)
			CPrintToChat(client, "%t", "HearHint");
	}

	return Plugin_Continue;
}


Action HearCmd(int client, int args)
{
	if (GetClientTeam(client) != TEAM_SPECTATOR)
		return Plugin_Handled;

	if (args >= 1)
	{
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));

		HearMode mode;
		if (!ParseHearMode(arg, mode))
		{
			CPrintToChat(client, "%t", "HearUsage");
			return Plugin_Handled;
		}

		g_HearMode[client] = mode;
		ApplyHearMode(client);

		char label[64];
		FormatEx(label, sizeof(label), "%T", HearModePhrase(mode), client);
		CPrintToChat(client, "%t", "HearSet", label);

		return Plugin_Handled;
	}

	char title[64];
	FormatEx(title, sizeof(title), "%T", "HearMenuTitle", client);

	Panel panel = new Panel();
	panel.SetTitle(title);

	DrawHearItem(panel, client, "HearSurvivors",      Hear_Survivors);
	DrawHearItem(panel, client, "HearInfected",       Hear_Infected);
	DrawHearItem(panel, client, "HearOnlySpectators", Hear_Spectators);
	DrawHearItem(panel, client, "HearAll",            Hear_All);

	panel.Send(client, HearPanelHandler, 20);
	delete panel;

	return Plugin_Handled;
}

void DrawHearItem(Panel panel, int client, const char[] phrase, HearMode mode)
{
	char text[64];
	FormatEx(text, sizeof(text), "%T%s", phrase, client, g_HearMode[client] == mode ? " *" : "");
	panel.DrawItem(text);
}

int HearPanelHandler(Menu menu, MenuAction menuAction, int client, int selected)
{
	if (menuAction != MenuAction_Select || GetClientTeam(client) != TEAM_SPECTATOR)
		return 0;

	switch (selected)
	{
		case 1: g_HearMode[client] = Hear_Survivors;
		case 2: g_HearMode[client] = Hear_Infected;
		case 3: g_HearMode[client] = Hear_Spectators;
		case 4: g_HearMode[client] = Hear_All;
		default: return 0;
	}

	ApplyHearMode(client);
	return 0;
}

Action BroadcastCmd(int client, int args)
{
	if (client <= 0 || !IsClientInGame(client))
		return Plugin_Handled;

	g_Broadcasting[client] = !g_Broadcasting[client];

	RefreshAllSpectators();

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	CPrintToChatAll("%t", g_Broadcasting[client] ? "BroadcastStarted" : "BroadcastStopped", name);

	return Plugin_Handled;
}

void RefreshEvent(Event event, const char[] name, bool dontBroadcast)
{
	RequestFrame(RefreshFrame);
}

void RefreshConVar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	RefreshAllSpectators();
}

void RefreshFrame(any data)
{
	RefreshAllSpectators();
}

void RefreshAllSpectators()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
			ApplyHearMode(client);
	}
}

void ApplyHearMode(int client)
{
	if (!IsClientInGame(client))
		return;

	HearMode mode = g_HearMode[client];
	bool isSpectator = GetClientTeam(client) == TEAM_SPECTATOR;
	bool useCustomHearing = isSpectator && !IsAllTalk();

	for (int target = 1; target <= MaxClients; target++)
	{
		if (target == client || !IsClientInGame(target) || IsFakeClient(target))
			continue;

		ListenOverride override = Listen_Default;

		if (g_Broadcasting[target])
			override = Listen_Yes;
		else if (useCustomHearing)
			override = ListenDecision(mode, GetClientTeam(target));

		SetListenOverride(client, target, override);
	}
}

bool ParseHearMode(const char[] arg, HearMode &mode)
{
	if (StrEqual(arg, "survivor", false) || StrEqual(arg, "survivors", false) || StrEqual(arg, "surv", false) || StrEqual(arg, "2"))
	{
		mode = Hear_Survivors;
		return true;
	}

	if (StrEqual(arg, "infected", false) || StrEqual(arg, "infec", false) || StrEqual(arg, "zombie", false) || StrEqual(arg, "3"))
	{
		mode = Hear_Infected;
		return true;
	}

	if (StrEqual(arg, "spectator", false) || StrEqual(arg, "spectators", false) || StrEqual(arg, "spec", false) || StrEqual(arg, "1"))
	{
		mode = Hear_Spectators;
		return true;
	}

	if (StrEqual(arg, "all", false) || StrEqual(arg, "everyone", false) || StrEqual(arg, "0"))
	{
		mode = Hear_All;
		return true;
	}

	return false;
}

char[] HearModePhrase(HearMode mode)
{
	char phrase[24];

	switch (mode)
	{
		case Hear_Survivors:  phrase = "HearSurvivors";
		case Hear_Infected:   phrase = "HearInfected";
		case Hear_Spectators: phrase = "HearOnlySpectators";
		default:              phrase = "HearAll";
	}

	return phrase;
}

ListenOverride ListenDecision(HearMode mode, int targetTeam)
{
	switch (targetTeam)
	{
		case TEAM_SPECTATOR: return Listen_Yes;
		case TEAM_SURVIVOR:  return (mode == Hear_Survivors || mode == Hear_All) ? Listen_Yes : Listen_No;
		case TEAM_ZOMBIE:    return (mode == Hear_Infected  || mode == Hear_All) ? Listen_Yes : Listen_No;
	}

	return Listen_Default;
}

bool IsAllTalk()
{
	return g_AllTalk != null && g_AllTalk.BoolValue;
}
