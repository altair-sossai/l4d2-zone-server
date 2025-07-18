#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define ENTITY_SAFE_LIMIT 2000
#define ZC_TANK 8

bool g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    EngineVersion test = GetEngineVersion();

    if (test != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    g_bLateLoad = late;

    return APLRes_Success;
}

ConVar g_hCvarColorGhost, 
       g_hCvarColorAlive;

int g_iCvarColorGhost, 
    g_iCvarColorAlive, 
    g_iModelIndex[MAXPLAYERS+1];

bool g_bMapStarted;

public Plugin myinfo =
{
    name = "l4d2 specating cheat",
    author = "Harry Potter",
    description = "A spectator who watching the survivor at first person view would see the infected model glows though the wall",
    version = "2.6",
    url = "https://steamcommunity.com/profiles/76561198026784913"
}

public void OnPluginStart()
{
    g_hCvarColorGhost = CreateConVar("l4d2_specting_cheat_ghost_color", "255 255 255", "Ghost SI glow color, Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
    g_hCvarColorAlive = CreateConVar("l4d2_specting_cheat_alive_color", "255 0 0", "Alive SI glow color, Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);

    GetCvars();

    g_hCvarColorGhost.AddChangeHook(ConVarChanged_Glow_Ghost);
    g_hCvarColorAlive.AddChangeHook(ConVarChanged_Glow_Alive);

    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("mission_lost", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);

    if (g_bLateLoad)
    {
        g_bMapStarted = true;
        CreateAllModelGlow();
    }
}

public void OnPluginEnd()
{
    RemoveAllModelGlow();
}

public void OnMapStart()
{
    g_bMapStarted = true;
}

public void OnMapEnd()
{
    g_bMapStarted = false;
}

public void OnClientDisconnect(int client)
{
    RemoveInfectedModelGlow(client);
}

void OnTankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllModelGlow();
    CreateAllModelGlow();
}

public void L4D_OnReplaceTank(int tank, int newtank)
{
    RemoveAllModelGlow();
    CreateAllModelGlow();
}

public void L4D_OnEnterGhostState(int client)
{
    RequestFrame(OnNextFrame, GetClientUserId(client));
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    RemoveInfectedModelGlow(client);
    RequestFrame(OnNextFrame, userid);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    RemoveInfectedModelGlow(client);
    RequestFrame(OnNextFrame, userid);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    RemoveInfectedModelGlow(client);
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int oldteam = event.GetInt("oldteam");

    RemoveInfectedModelGlow(client);

    if (client && IsClientInGame(client) && !IsFakeClient(client) && oldteam == L4D_TEAM_SPECTATOR)
    {
        RemoveAllModelGlow();
        CreateAllModelGlow();
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    RemoveAllModelGlow();
}

void CreateInfectedModelGlow(int client)
{
    if (!client || !IsClientInGame(client) || GetClientTeam(client) != L4D_TEAM_INFECTED || !IsPlayerAlive(client) || !g_bMapStarted)
        return;

    if (IsPlayerGhost(client) && GetZombieClass(client) == ZC_TANK)
        CreateTimer(0.25, Timer_CheckGhostTank, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

    int entity = CreateEntityByName("prop_dynamic_ornament");

    if (!IsEntityWithinSafeLimit(entity))
        return;

    RemoveInfectedModelGlow(client);

    char sModelName[64];
    GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

    SetEntityModel(entity, sModelName);
    DispatchSpawn(entity);

    SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
    SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
    SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", IsPlayerGhost(client) ? g_iCvarColorGhost : g_iCvarColorAlive);
    AcceptEntityInput(entity, "StartGlowing");

    SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
    SetEntityRenderColor(entity, 0, 0, 0, 0);

    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", client);
    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetAttached", client);

    g_iModelIndex[client] = EntIndexToEntRef(entity);

    SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

void RemoveInfectedModelGlow(int client)
{
    int entity = g_iModelIndex[client];

    g_iModelIndex[client] = 0;

    if (IsValidEntRef(entity))
        AcceptEntityInput(entity, "Kill");
}

public Action Hook_SetTransmit(int entity, int client)
{
    if (GetClientTeam(client) == L4D_TEAM_SPECTATOR)
        return Plugin_Continue;

    return Plugin_Handled;
}

int GetColor(char[] sTemp)
{
    if (StrEqual(sTemp, ""))
        return 0;

    char sColors[3][4];
    int color = ExplodeString(sTemp, " ", sColors, 3, 4);

    if (color != 3)
        return 0;

    color = StringToInt(sColors[0]);
    color += 256 * StringToInt(sColors[1]);
    color += 65536 * StringToInt(sColors[2]);

    return color;
}

public void ConVarChanged_Glow_Ghost(Handle convar, const char[] oldValue, const char[] newValue) 
{
    GetCvars();

    int entity;
    for (int i=1; i<=MaxClients ; ++i)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == L4D_TEAM_INFECTED && IsPlayerGhost(i))
        {
            entity = g_iModelIndex[i];
            if (entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
            {
                SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarColorGhost);
            }
        }
    }
}

public void ConVarChanged_Glow_Alive(Handle convar, const char[] oldValue, const char[] newValue) 
{
    GetCvars();

    int entity;
    for (int i=1; i<=MaxClients ; ++i)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == L4D_TEAM_INFECTED && IsPlayerAlive(i) && !IsPlayerGhost(i))
        {
            entity = g_iModelIndex[i];
            if (entity && (entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE)
            {
                SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
                SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarColorAlive);
            }
        }
    }
}

void GetCvars()
{
    char sColor[16],sColor2[16];
    g_hCvarColorGhost.GetString(sColor, sizeof(sColor));
    g_iCvarColorGhost = GetColor(sColor);
    g_hCvarColorAlive.GetString(sColor2, sizeof(sColor2));
    g_iCvarColorAlive = GetColor(sColor2);
}

bool IsPlayerGhost(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

bool IsValidEntRef(int entity)
{
    if (entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
        return true;
    return false;
}

void RemoveAllModelGlow()
{
    for (int i = 1; i <= MaxClients; i++)
        RemoveInfectedModelGlow(i);
}

void CreateAllModelGlow()
{
    if (!g_bMapStarted) 
        return;

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client)) 
            continue;

        RequestFrame(OnNextFrame, GetClientUserId(client));
    }
}

void OnNextFrame(int userid)
{
    CreateInfectedModelGlow(GetClientOfUserId(userid));
}

Action Timer_CheckGhostTank(Handle timer, int userid)
{
    int tank = GetClientOfUserId(userid);

    CreateInfectedModelGlow(tank);

    return Plugin_Continue;
}

bool IsEntityWithinSafeLimit(int entity)
{
    if (entity == -1) 
        return false;

    if (entity > ENTITY_SAFE_LIMIT)
    {
        AcceptEntityInput(entity, "Kill");
        return false;
    }

    return true;
}

int GetZombieClass(int client)
{
    return GetEntProp(client, Prop_Send, "m_zombieClass");
}