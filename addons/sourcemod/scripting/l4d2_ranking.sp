#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <readyup>

public Plugin myinfo =
{
    name        = "L4D2 - Ranking",
    author      = "Altair Sossai",
    description = "Shows the ranking of the players",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar hUrl;

bool showRankingEnabled = true;
bool displayed[MAXPLAYERS + 1] = { false, ... };

public void OnPluginStart()
{
    hUrl = CreateConVar("ranking_url", "", "Ranking site URL", FCVAR_PROTECTED);

    RegConsoleCmd("sm_ranking", ShowRankingCmd);

    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);

    CreateTimer(200.0, DisplayRankingUrlTick, _, TIMER_REPEAT);
}

public void OnRoundIsLive()
{
    showRankingEnabled = false;
    ResetRankingDisplayed();
}

public void OnClientPutInServer(int client)
{
    displayed[client] = false;

    if (!IsFakeClient(client))
        CreateTimer(60.0, ShowRankingTick, client);
}

void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, NewGameTick);
}

Action NewGameTick(Handle timer)
{
    showRankingEnabled = IsNewGame();

    return Plugin_Stop;
}

Action ShowRankingCmd(int client, int args)
{
    ShowRanking(client);
    return Plugin_Handled;
}

Action DisplayRankingUrlTick(Handle timer)
{
    if (!showRankingEnabled)
        return Plugin_Continue;

    PrintToChatAll("\x03l4d2.com.br");
    PrintToChatAll("\x04!ranking \x01to check your position");

    return Plugin_Continue;
}

Action ShowRankingTick(Handle timer, int client)
{
    if (showRankingEnabled && !displayed[client])
        ShowRanking(client);

    return Plugin_Stop;
}

void ShowRanking(int client)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    displayed[client] = true;

    char url[100];
    GetConVarString(hUrl, url, sizeof(url));

    char path[128];
    FormatEx(path, sizeof(path), "%s/ranking", url);

    ShowMOTDPanel(client, "L4D2 | Players Ranking", path, MOTDPANEL_TYPE_URL);
}

bool IsNewGame()
{
    return L4D2Direct_GetVSCampaignScore(0) == 0 && L4D2Direct_GetVSCampaignScore(1) == 0;
}

void ResetRankingDisplayed()
{
    for (int i = 0; i <= MaxClients; i++)
        displayed[i] = false;
}