#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2

#define DELAY_TIME_IN_SECONDS 5.0

float LastDamageReceivedOn[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "L4D2 - No Skip Getup Animation",
    author = "Altair Sossai",
    description = "Prevents players from skipping the getup animation",
    version = "1.0.0",
    url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
    AddCommandListener(Spectate_Callback, "sm_spectate");
    AddCommandListener(Spectate_Callback, "sm_spec");
    AddCommandListener(Spectate_Callback, "sm_s");
    AddCommandListener(JoinTeam_Callback, "jointeam");

    HookEvent("round_start", RoundStart_Event);
    HookEvent("player_hurt", PlayerHurt_Event);

    ClearLastDamageReceivedOn();
}

Action Spectate_Callback(int client, char[] command, int args)
{
    return CanGoToSpec(client) ? Plugin_Continue : Plugin_Handled; 
}

Action JoinTeam_Callback(int client, char[] command, int args)
{
    if (args == 0)
        return Plugin_Continue;

    char buffer[128];
    GetCmdArg(1, buffer, sizeof(buffer));

    if (StrEqual("Survivors", buffer, false) || StrEqual("2", buffer, false))
        return Plugin_Continue;

    return CanGoToSpec(client) ? Plugin_Continue : Plugin_Handled; 
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    ClearLastDamageReceivedOn();
}

void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR) 
        return;

    LastDamageReceivedOn[client] = GetEngineTime();
}

void ClearLastDamageReceivedOn()
{
    for (int i = 1; i <= MaxClients; i++)
        LastDamageReceivedOn[i] = 0.0;
}

bool CanGoToSpec(int client)
{
    if (GetClientTeam(client) != TEAM_SURVIVOR)
        return true;

    return (GetEngineTime() - LastDamageReceivedOn[client]) >= DELAY_TIME_IN_SECONDS;
}