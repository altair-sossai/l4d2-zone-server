/*
    v0.1:
    - Untested, think it's fine but I did write it at 1am.

*/

#pragma newdecls required
#pragma semicolon 1

// Force %0 to be between %1 and %2.
#define CLAMP(%0,%1,%2) (((%0) > (%2)) ? (%2) : (((%0) < (%1)) ? (%1) : (%0)))

#define TEAM_SURVIVOR 2

#include <sourcemod>

bool
    bEnabled,
    bRevive;

ConVar
    ConVar_Enabled,
    ConVar_ReviveSurvivor,
    ConVar_ValvePillsDecay;

float
    fValvePillsDecay;

public Plugin myinfo =
{
    name = "[L4D2] Admin HP",
    author = "Sir",
    description = "Allow Admins with the kick flag to give health to Survivors with the use of !hp (sm_hp)",
    version = "0.1",
    url = "URL"
};

public void OnPluginStart()
{
    /* ConVars */
    ConVar_Enabled         = CreateConVar("l4d2_admhp_enabled", "1", "Enable Plugin?", FCVAR_SPONLY, true, 0.0, true, 1.0);
    ConVar_ReviveSurvivor  = CreateConVar("l4d2_admhp_revive", "0", "Revive incapacitated Survivors when the HP command is used?", FCVAR_SPONLY, true, 0.0, true, 1.0);
    ConVar_ValvePillsDecay = FindConVar("pain_pills_decay_rate");

    ConVar_Enabled.AddChangeHook(CVarChanged);
    ConVar_ReviveSurvivor.AddChangeHook(CVarChanged);
    ConVar_ValvePillsDecay.AddChangeHook(CVarChanged);

    /* Commands */
    RegAdminCmd("sm_hp", Cmd_Health, ADMFLAG_KICK);

    /* Trigger CVarChanged to get all variables set */
    CVarChanged(ConVar_Enabled, "1", "1");
}

void CVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    bEnabled         = ConVar_Enabled.BoolValue;
    bRevive          = ConVar_ReviveSurvivor.BoolValue;
    fValvePillsDecay = ConVar_ValvePillsDecay.FloatValue;
}

Action Cmd_Health(int client, int args)
{
    if (!bEnabled || (client && !IsClientInGame(client)))
        return Plugin_Handled;

    int healthToGive = 100;

    // Assume specific amount of health if an argument is given
    if (args)
    {
        char buffer[100];
        GetCmdArg(1, buffer, sizeof(buffer));
        int healthBuffer = StringToInt(buffer);

        if (0 < healthBuffer <= healthToGive)
            healthToGive = healthBuffer;
    }

    int newHealth, roundedTempHealth, finalHealth, overhealth;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
            continue;

        if (IsIncapacitated(i))
        {
            if (bRevive)
            {
                RevivePlayer(i);
                SetEntityHealth(i, healthToGive);
            }
            continue;
        }

        /*
            First we ensure that the player will never go over 100 Health
            Then we will reduce temporary health if their health + temp health exceeds 100
        */

        newHealth = GetClientHealth(i) + healthToGive;
        SetEntityHealth(i, CLAMP(newHealth, healthToGive, 100));

        roundedTempHealth = RoundToFloor(GetTempHealth(i));
        finalHealth = newHealth + roundedTempHealth;
        overhealth = finalHealth - 100;

        if (overhealth > 0)
            SetTempHealth(client, float(roundedTempHealth - overhealth));
    }
    return Plugin_Handled;
}

/**
* Get a client their temporary health
*
* @remark Stock from Left4DHooks!
* @param  client client index
* @return temporary health
*/
float GetTempHealth(int client)
{
    float fGameTime = GetGameTime();
    float fHealthTime = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
    float fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    fHealth -= (fGameTime - fHealthTime) * fValvePillsDecay;
    return fHealth < 0.0 ? 0.0 : fHealth;
}

/**
* Set a client their temporary health
*
* @remark Stock from Left4DHooks!
* @param client  client index
* @param fHealth temporary health
* @noreturn
*/
void SetTempHealth(int client, float fHealth)
{
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", fHealth < 0.0 ? 0.0 : fHealth);
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

/**
* Check if a client is incapacitated
*
* @param  client client index
* @return true if the client is incapacitated, false otherwise
*/
bool IsIncapacitated(int client)
{
    return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

/**
* Revives a player and increases their revive count accordingly.
*
* @remark the client will revive with their current "incap health"
* @param client client index
* @noreturn
*/
void RevivePlayer(int client)
{
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

    int reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
    SetEntProp(client, Prop_Send, "m_currentReviveCount", reviveCount + 1);
}