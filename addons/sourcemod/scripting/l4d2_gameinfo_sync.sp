#pragma semicolon 1
#pragma newdecls required

#include <ripext>
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>
#include <l4d2util>
#include <colors>
#include <l4d2_hybrid_scoremod>

#define L4D2_TEAM_SPECTATOR 1
#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

public Plugin myinfo =
{
    name        = "L4D2 - Game Info Sync",
    author      = "Altair Sossai",
    description = "Syncs game info with Game Info API",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar
    hUrl,
    hSecretKey,
    hConfigurationName;

char ConfigurationName[64];

bool InTransition = false;

int InfectedDamage[MAXPLAYERS + 1];

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    AddCommandListener(Say_Callback, "say");
    AddCommandListener(Say_Callback, "say_team");

    HookEvent("round_start", RoundStart_Event);
    HookEvent("player_hurt", PlayerHurt_Event);
    HookEvent("player_disconnect", PlayerDisconnect_Event);

    CreateTimer(5.0, Every_5_Seconds_Timer, _, TIMER_REPEAT);

    ClearInfectedDamage();
}

public void OnRoundIsLive()
{
    InTransition = false;
}

public void L4D2_OnEndVersusModeRound_Post()
{
    InTransition = true;
}

Action Say_Callback(int client, char[] command, int args)
{
    if (args == 0)
        return Plugin_Continue;

    if (!StrEqual("say", command) && !StrEqual("say_team", command))
        return Plugin_Continue;

    char message[MAX_MESSAGE_LENGTH];
    GetCmdArg(1, message, sizeof(message));

    if (strlen(message) == 0 || message[0] == '!')
        return Plugin_Continue;

    JSONObject jObject = new JSONObject();

    jObject.SetInt("when", GetTime());
    jObject.SetBool("public", StrEqual("say", command));
    jObject.SetInt("team", GetClientTeam(client));

    char communityId[25];
    GetClientAuthId(client, AuthId_SteamID64, communityId, sizeof(communityId));
    jObject.SetString("communityId", communityId);

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    jObject.SetString("name", name);

    jObject.SetString("message", message);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/messages");
    
    request.Put(jObject, DoNothing);

    return Plugin_Continue; 
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    ClearInfectedDamage();
    CreateTimer(5.0, RoundStart_Timer);
}

void PlayerHurt_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != L4D2_TEAM_INFECTED)
	    return;
	
	InfectedDamage[attacker] += GetEventInt(event, "dmg_health");
}

void PlayerDisconnect_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > -1 && client <= MAXPLAYERS)
        InfectedDamage[client] = 0;
}

Action RoundStart_Timer(Handle timer)
{
    InTransition = false;

    SendConfiguration();
    SendRound();

    return Plugin_Continue;
}

Action Every_5_Seconds_Timer(Handle hTimer)
{
    SendScoreboard();
    SendPlayers();

    return Plugin_Continue;
}

void SendConfiguration()
{
    if (InTransition)
        return;

    JSONObject command = new JSONObject();

    command.SetInt("teamSize", GetConVarInt(FindConVar("survivor_limit")));

    if (hConfigurationName == null)
        hConfigurationName = FindConVar("l4d_ready_cfg_name");

    if (hConfigurationName != null)
        hConfigurationName.GetString(ConfigurationName, sizeof(ConfigurationName));

    if (strlen(ConfigurationName) > 0)
        command.SetString("name", ConfigurationName);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/configuration");
    
    request.Put(command, DoNothing);
}

void SendRound()
{
    if (InTransition)
        return;

    JSONObject command = new JSONObject();

    command.SetInt("areTeamsFlipped", GameRules_GetProp("m_bAreTeamsFlipped"));
    command.SetInt("maxChapterProgressPoints", L4D_GetVersusMaxCompletionScore());

    HTTPRequest request = BuildHTTPRequest("/api/game-info/round");

    request.Put(command, DoNothing);
}

void SendScoreboard()
{
    if (InTransition)
        return;

    JSONObject command = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    command.SetInt("survivorScore", L4D2Direct_GetVSCampaignScore(flipped ? 1 : 0) + L4D_GetTeamScore(flipped ? 2 : 1));
    command.SetInt("infectedScore", L4D2Direct_GetVSCampaignScore(flipped ? 0 : 1) + L4D_GetTeamScore(flipped ? 1 : 2));
    command.SetInt("bonus", SMPlus_GetHealthBonus() + SMPlus_GetDamageBonus() + SMPlus_GetPillsBonus());
    command.SetInt("maxBonus", SMPlus_GetMaxHealthBonus() + SMPlus_GetMaxDamageBonus() + SMPlus_GetMaxPillsBonus());

    HTTPRequest request = BuildHTTPRequest("/api/game-info/scoreboard");

    request.Put(command, DoNothing);
}

void SendPlayers()
{
    if (InTransition)
        return;

    JSONObject command = new JSONObject();

    JSONArray survivors = new JSONArray();
    JSONArray infecteds = new JSONArray();
    JSONArray spectators = new JSONArray();

    char communityId[25];
    char name[MAX_NAME_LENGTH];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        int team = GetClientTeam(client);
        if (team != L4D2_TEAM_SPECTATOR && team != L4D2_TEAM_SURVIVOR && team != L4D2_TEAM_INFECTED)
            continue;

        JSONObject player = new JSONObject();

        GetClientAuthId(client, AuthId_SteamID64, communityId, sizeof(communityId));
        player.SetString("communityId", communityId);

        GetClientName(client, name, sizeof(name));
        player.SetString("name", name);

        player.SetFloat("latency", GetClientLatency(client, NetFlow_Both));

        if (team == L4D2_TEAM_SURVIVOR)
        {
            player.SetInt("character", IdentifySurvivor(client));
            player.SetInt("permanentHealth", GetSurvivorPermanentHealth(client));
            player.SetInt("temporaryHealth", GetSurvivorTemporaryHealth(client));
            player.SetInt("primaryWeapon", IdentifyWeapon(GetPlayerWeaponSlot(client, 0)));

            int slot1 = GetPlayerWeaponSlot(client, 1);
            int secondaryWeapon = IdentifyWeapon(slot1);

            player.SetInt("secondaryWeapon", secondaryWeapon);

            if (secondaryWeapon == WEPID_MELEE)
                player.SetInt("meleeWeapon", IdentifyMeleeWeapon(slot1));

            player.SetInt("slotNumber3", IdentifyWeapon(GetPlayerWeaponSlot(client, 2)));
            player.SetInt("slotNumber4", IdentifyWeapon(GetPlayerWeaponSlot(client, 3)));
            player.SetInt("slotNumber5", IdentifyWeapon(GetPlayerWeaponSlot(client, 4)));
            player.SetBool("blackAndWhite", L4D_IsPlayerOnThirdStrike(client));
            player.SetBool("incapacitated", IsIncapacitated(client));
            player.SetBool("isPlayerAlive", IsPlayerAlive(client));
            player.SetFloat("progress", GetSurvivorProgress(client));

            survivors.Push(player);
        }

        if (team == L4D2_TEAM_INFECTED)
        {
            player.SetInt("type", GetInfectedClass(client));
            player.SetInt("DamageTotal", InfectedDamage[client]);
            player.SetInt("health", GetClientHealth(client));
            player.SetInt("maxHealth", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
            player.SetBool("isInfectedGhost", IsInfectedGhost(client));
            player.SetBool("isPlayerAlive", IsPlayerAlive(client));

            infecteds.Push(player);
        }
        
        if (team == L4D2_TEAM_SPECTATOR)
            spectators.Push(player);
    }

    command.Set("survivors", survivors);
    command.Set("infecteds", infecteds);
    command.Set("spectators", spectators);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/players");

    request.Put(command, DoNothing);
}

void DoNothing(HTTPResponse httpResponse, any value)
{
}

HTTPRequest BuildHTTPRequest(char[] path)
{
    char url[255];
    GetConVarString(hUrl, url, sizeof(url));
    StrCat(url, sizeof(url), path);

    char secretKey[100];
    GetConVarString(hSecretKey, secretKey, sizeof(secretKey));

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Authorization", secretKey);

    return request;
}

void ClearInfectedDamage()
{
    for (int i = 1; i <= MaxClients; i++)
        InfectedDamage[i] = 0;
}

float GetSurvivorProgress(int client)
{
    float origin[3];
    GetClientAbsOrigin(client, origin);

    Address navArea = L4D2Direct_GetTerrorNavArea(origin);
    if (navArea != Address_Null)
        return Max(0.0, Min(L4D2Direct_GetTerrorNavAreaFlow(navArea) / L4D2Direct_GetMapMaxFlowDistance(), 1.0));
	
    return 0.0;
}

float Max(float a, float b) {
    return (a > b) ? a : b;
}

float Min(float a, float b) {
    return (a < b) ? a : b;
}