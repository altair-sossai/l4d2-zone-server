#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <pause>
#include <colors>
#include <l4d2util_constants>

public Plugin myinfo =
{
    name = "L4D2 - Block Spec During Tank",
    author = "Altair Sossai",
    description = "Prevents survivors from changing team while the tank is alive, unless the game is paused",
    version = "1.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_block_spec_during_tank.phrases");

    AddCommandListener(ChangeTeam_Callback, "sm_spectate");
    AddCommandListener(ChangeTeam_Callback, "sm_spec");
    AddCommandListener(ChangeTeam_Callback, "sm_s");
    AddCommandListener(ChangeTeam_Callback, "jointeam");
}

Action ChangeTeam_Callback(int client, char[] command, int args)
{
    return CanChangeTeam(client) ? Plugin_Continue : Blocked(client);
}

Action Blocked(int client)
{
    CPrintToChat(client, "{orange}[%t] {default}%t", "Tag", "BlockedTankAlive");

    return Plugin_Handled;
}

bool CanChangeTeam(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return true;

    if (GetClientTeam(client) != TEAM_SURVIVOR)
        return true;

    if (IsInPause())
        return true;

    return !IsTankInPlay();
}

bool IsTankInPlay()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_ZOMBIE || !IsPlayerAlive(i))
            continue;

        if (GetEntProp(i, Prop_Send, "m_zombieClass") == view_as<int>(L4D2ZombieClass_Tank))
            return true;
    }

    return false;
}
