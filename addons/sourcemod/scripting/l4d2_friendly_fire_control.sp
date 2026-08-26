#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>
#include <colors>

ConVar g_cvEnabled;
ConVar g_cvInterval;
ConVar g_cvDecrement;
ConVar g_cvLimit;
ConVar g_cvMinHealth;

float g_fFriendlyFire[MAXPLAYERS + 1];

Handle g_hRecoverTimer = null;
bool g_bActive = false;

public Plugin myinfo =
{
    name = "L4D2 - Friendly Fire Control",
    author = "Altair Sossai",
    description = "Tracks friendly fire between human survivors and kicks players who exceed the friendly fire limit",
    version = "1.0.0",
    url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_friendly_fire_control.phrases");

    g_cvEnabled = CreateConVar("l4d2_friendly_fire_control_enabled", "1", "Enables the friendly fire control", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvInterval = CreateConVar("l4d2_friendly_fire_control_interval", "1.0", "Interval, in seconds, at which each player's accumulated friendly fire damage is reduced", FCVAR_NOTIFY, true, 0.1);
    g_cvDecrement = CreateConVar("l4d2_friendly_fire_control_decrement", "1.0", "How much is subtracted from the accumulated friendly fire damage on every recovery interval", FCVAR_NOTIFY, true, 0.0);
    g_cvLimit = CreateConVar("l4d2_friendly_fire_control_limit", "20.0", "Accumulated friendly fire damage that gets a player kicked", FCVAR_NOTIFY, true, 1.0);
    g_cvMinHealth = CreateConVar("l4d2_friendly_fire_control_min_health", "10.0", "Friendly fire is ignored when the victim's total health (permanent + temporary) is at or below this value (e.g. mercy downs on low-health teammates)", FCVAR_NOTIFY, true, 0.0);

    HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
}

public void OnRoundIsLive()
{
    StartControl();
}

public void L4D2_OnEndVersusModeRound_Post()
{
    StopControl();
}

void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
    StopControl();
}

public void OnMapEnd()
{
    StopControl();
}

public void OnClientDisconnect(int client)
{
    if (client >= 1 && client <= MaxClients)
        g_fFriendlyFire[client] = 0.0;
}

void StartControl()
{
    StopControl();

    g_bActive = true;
    g_hRecoverTimer = CreateTimer(g_cvInterval.FloatValue, Recover_Timer, _, TIMER_REPEAT);
}

void StopControl()
{
    if (g_hRecoverTimer != null)
    {
        KillTimer(g_hRecoverTimer);
        g_hRecoverTimer = null;
    }

    g_bActive = false;

    ResetCounters();
}

void ResetCounters()
{
    for (int client = 1; client <= MaxClients; client++)
        g_fFriendlyFire[client] = 0.0;
}

Action Recover_Timer(Handle timer)
{
    float decrement = g_cvDecrement.FloatValue;

    for (int client = 1; client <= MaxClients; client++)
        g_fFriendlyFire[client] = FloatMax(g_fFriendlyFire[client] - decrement, 0.0);

    return Plugin_Continue;
}

void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bActive || !g_cvEnabled.BoolValue)
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));

    if (attacker == victim)
        return;

    if (!IsHumanSurvivor(attacker) || !IsHumanSurvivor(victim))
        return;

    if (!IsStanding(victim))
        return;

    if (IsSurvivorAttacked(victim))
        return;

    if (float(TotalHealth(victim)) <= g_cvMinHealth.FloatValue)
        return;

    int damage = event.GetInt("dmg_health");
    if (damage <= 0)
        return;

    g_fFriendlyFire[attacker] += float(damage);

    if (g_fFriendlyFire[attacker] >= g_cvLimit.FloatValue)
        KickForFriendlyFire(attacker);
}

void KickForFriendlyFire(int client)
{
    g_fFriendlyFire[client] = 0.0;

    CPrintToChatAll("{orange}[%t] {default}%t", "Tag", "Announce", client);

    char reason[192];
    Format(reason, sizeof(reason), "%T", "KickReason", client);
    KickClient(client, "%s", reason);
}

bool IsHumanSurvivor(int client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return false;

    return GetClientTeam(client) == L4D_TEAM_SURVIVOR;
}

bool IsStanding(int client)
{
    if (!IsPlayerAlive(client))
        return false;

    if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) > 0)
        return false;

    if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge", 1) > 0)
        return false;

    if (GetEntProp(client, Prop_Send, "m_isFallingFromLedge", 1) > 0)
        return false;

    return true;
}

int TotalHealth(int client)
{
    return GetSurvivorPermanentHealth(client) + GetSurvivorTemporaryHealth(client);
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients)
        return false;

    return IsClientInGame(client);
}

float FloatMax(float a, float b)
{
    return a > b ? a : b;
}
