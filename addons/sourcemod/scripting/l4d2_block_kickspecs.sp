#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

public Plugin myinfo = 
{
    name = "Block KickSpecs",
    author = "Altair Sossai",
    description = "Prevents the use of sm_kickspecs if there is only one player on the team",
    version = "1.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    AddCommandListener(Command_KickSpecs, "sm_kickspecs");
}

int TeamSize()
{
    return GetConVarInt(FindConVar("survivor_limit"));
}

public Action Command_KickSpecs(int client, const char[] command, int argc)
{
    if (client == 0 || !IsClientInGame(client))
        return Plugin_Continue;

    int team = GetClientTeam(client);
    if (team != TEAM_SURVIVORS && team != TEAM_INFECTED)
        return Plugin_Continue;

    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        if (GetClientTeam(i) != TEAM_SURVIVORS && GetClientTeam(i) != TEAM_INFECTED)
            continue;

        count++;
    }

    if (count < TeamSize())
    {
        PrintToChat(client, "\x05[SM] \x01You cannot use sm_kickspecs with insufficient players.");
        return Plugin_Handled;
    }

    return Plugin_Continue;
}
