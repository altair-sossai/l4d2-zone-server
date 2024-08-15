#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VOICE_NORMAL        0   /**< Allow the client to listen and speak normally. */
#define VOICE_MUTED         1   /**< Mutes the client from speaking to everyone. */
#define VOICE_SPEAKALL      2   /**< Allow the client to speak to everyone. */
#define VOICE_LISTENALL     4   /**< Allow the client to listen to everyone. */
#define VOICE_TEAM          8   /**< Allow the client to always speak to team, even when dead. */
#define VOICE_LISTENTEAM    16  /**< Allow the client to always hear teammates, including dead ones. */

#define TEAM_SPEC 1

public Plugin myinfo =
{
	name = "Spec Lister",
	author = "Altair Sossai",
	description = "Allow spectators to listen to all players",
	version = "1.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
}

public void OnPluginStart()
{
	HookEvent("player_team", PlayerTeam_Event);

	RegConsoleCmd("sm_hear", Hear_Cmd, "Allow spectators to listen to all players");
}

public void OnClientPutInServer(int client)
{
	CreateTimer(40.0, ShowMessage_Tick, client);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	SetClientListeningFlags(client, GetEventInt(event, "team") == TEAM_SPEC ? VOICE_LISTENALL : VOICE_NORMAL);
}

Action Hear_Cmd(int client, int args)
{
	if(GetClientTeam(client) != TEAM_SPEC)
		return Plugin_Handled;

	Handle panel = CreatePanel();

	SetPanelTitle(panel, "Who you want to hear?");
	DrawPanelItem(panel, "All players");
	DrawPanelItem(panel, "Only spectators");
	DrawPanelItem(panel, "Nobody");
 
	SendPanelToClient(panel, client, HearPanel_Handler, 20);
 
	CloseHandle(panel);
 
	return Plugin_Handled;
}

int HearPanel_Handler(Menu menu, MenuAction menuAction, int client, int selected)
{
	if (menuAction != MenuAction_Select || GetClientTeam(client) != TEAM_SPEC)
		return -1;

	int flag = selected == 1 ? VOICE_LISTENALL
			 : selected == 2 ? VOICE_NORMAL
			 : selected == 3 ? VOICE_MUTED
			 : -1;

	if(flag != -1)
		SetClientListeningFlags(client, flag);

	return flag;
}

Action ShowMessage_Tick(Handle timer, int client)
{
	if (client == 0 || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != TEAM_SPEC)
		return Plugin_Stop;

	PrintToChat(client, "\x04[Listen/Mute] \x01To listen to or mute players, type: \03!hear");

	return Plugin_Stop;
}