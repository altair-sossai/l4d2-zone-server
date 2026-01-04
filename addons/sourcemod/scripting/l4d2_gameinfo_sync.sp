#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <ripext>
#include <colors>
#include <l4d2util>

#undef REQUIRE_PLUGIN
#include <pause>
#include <readyup>
#include <l4d2_boss_percents>
#include <l4d2_hybrid_scoremod>

#define L4D2_TEAM_SPECTATOR 1
#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

#define ZOMBIECLASS_TANK 8

public Plugin myinfo =
{
    name        = "L4D2 - Game Info Sync",
    author      = "Altair Sossai",
    description = "Syncs game info with Game Info API",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar
    g_hUrl,
    g_hSecretKey,
    g_hConfigurationName,
    g_hVersusBossBuffer;

char 
    g_sConfigurationName[64],
    g_sLastMessage[32];

bool 
    g_bReadyUpIsAvailable = false,
    g_bPauseIsAvailable = false,
    g_bL4D2BossPercentsAvailable = false,
    g_bHybridScoremodIsAvailable = false,
    g_bInTransition = false,
    g_bTankIsDead = false;

int 
    g_iInfectedDamage[MAXPLAYERS + 1],
    g_iTankPercent,
    g_iWitchPercent;

float 
    g_fSurvivorProgress[MAXPLAYERS + 1];

public void OnPluginStart()
{
    g_hVersusBossBuffer = FindConVar("versus_boss_buffer");

    g_hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    g_hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    AddCommandListener(Say_Callback, "say");
    AddCommandListener(Say_Callback, "say_team");

    HookEvent("round_start", RoundStart_Event);
    HookEvent("player_hurt", PlayerHurt_Event);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("player_disconnect", PlayerDisconnect_Event);

    CreateTimer(5.0, SyncData_Timer, _, TIMER_REPEAT);

    ClearInfectedDamage();
    ClearSurvivorProgress();
}

public void OnAllPluginsLoaded()
{
    g_bReadyUpIsAvailable = LibraryExists("readyup");
    g_bPauseIsAvailable = LibraryExists("pause");
    g_bL4D2BossPercentsAvailable = LibraryExists("l4d_boss_percent");
    g_bHybridScoremodIsAvailable = LibraryExists("l4d2_hybrid_scoremod") || LibraryExists("l4d2_hybrid_scoremod_zone");
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "readyup") == 0)
        g_bReadyUpIsAvailable = false;

    if (strcmp(name, "pause") == 0)
        g_bPauseIsAvailable = false;

    if (strcmp(name, "l4d_boss_percent") == 0)
        g_bL4D2BossPercentsAvailable = false;

    if (strcmp(name, "l4d2_hybrid_scoremod") == 0 || strcmp(name, "l4d2_hybrid_scoremod_zone") == 0)
        g_bHybridScoremodIsAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "readyup") == 0)
        g_bReadyUpIsAvailable = true;

    if (strcmp(name, "pause") == 0)
        g_bPauseIsAvailable = true;

    if (strcmp(name, "l4d_boss_percent") == 0)
        g_bL4D2BossPercentsAvailable = true;

    if (strcmp(name, "l4d2_hybrid_scoremod") == 0 || strcmp(name, "l4d2_hybrid_scoremod_zone") == 0)
        g_bHybridScoremodIsAvailable = true;
}

public void OnRoundIsLive()
{
    g_bInTransition = false;
    g_bTankIsDead = false;

    ClearInfectedDamage();
    ClearSurvivorProgress();
    CreateTimer(2.0, OnRoundIsLive_Timer);
}

public void OnPause()
{
    SendRound();
}

public void OnUnpause()
{
    SendRound();
}

public void L4D2_OnEndVersusModeRound_Post()
{
    SendRound();
    SendScoreboard();
    SendPlayers();

    CreateTimer(2.5, L4D2_OnEndVersusModeRound_Post_Timer);
}

Action Say_Callback(int client, char[] command, int args)
{
    if (args == 0)
        return Plugin_Continue;

    if (!StrEqual("say", command) && !StrEqual("say_team", command))
        return Plugin_Continue;

    char message[MAX_MESSAGE_LENGTH];
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);

    if (strlen(message) == 0 || message[0] == '!' || message[0] == '/')
        return Plugin_Continue;

    JSONObject jObject = new JSONObject();

    jObject.SetBool("public", StrEqual("say", command));
    jObject.SetInt("team", GetClientTeam(client));

    char communityId[25];
    GetClientAuthId(client, AuthId_SteamID64, communityId, sizeof(communityId));
    jObject.SetString("communityId", communityId);

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    jObject.SetString("name", name);

    jObject.SetBool("isAdmin", CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN));

    jObject.SetString("message", message);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/messages");
    
    request.Put(jObject, DoNothing);

    return Plugin_Continue; 
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_bTankIsDead = false;

    ClearInfectedDamage();
    ClearSurvivorProgress();
    CreateTimer(5.0, RoundStart_Timer);
}

void PlayerHurt_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (attacker == 0 || !IsClientInGame(attacker) || GetClientTeam(attacker) != L4D2_TEAM_INFECTED)
	    return;
	
	g_iInfectedDamage[attacker] += GetEventInt(event, "dmg_health");
}

void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    if (g_bTankIsDead)
        return;

    int victim = GetClientOfUserId(hEvent.GetInt("userid"));
    
    if (victim == 0 || !IsClientInGame(victim) || GetClientTeam(victim) != L4D2_TEAM_INFECTED)
        return;

    g_bTankIsDead = GetEntProp(victim, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK;
}

void PlayerDisconnect_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > -1 && client <= MAXPLAYERS)
    {
        g_iInfectedDamage[client] = 0;
        g_fSurvivorProgress[client] = 0.0;
    }
}

Action RoundStart_Timer(Handle timer)
{
    g_bInTransition = false;

    SendConfiguration();
    SendRound();

    return Plugin_Continue;
}

Action L4D2_OnEndVersusModeRound_Post_Timer(Handle timer)
{
    g_bInTransition = true;

    return Plugin_Continue;    
}

Action OnRoundIsLive_Timer(Handle timer)
{
    SendRound();

    return Plugin_Continue;
}

Action SyncData_Timer(Handle hTimer)
{
    SendScoreboard();
    SendPlayers();

    if (!g_bInTransition && (g_iTankPercent != GetTankPercent() || g_iWitchPercent != GetWitchPercent()))
        SendRound();

    CheckForNewExternalMessages();
    CheckForNewServerCommands();

    return Plugin_Continue;
}

void SendConfiguration()
{
    if (g_bInTransition)
        return;

    JSONObject command = new JSONObject();

    command.SetInt("teamSize", GetConVarInt(FindConVar("survivor_limit")));

    if (g_hConfigurationName == null)
        g_hConfigurationName = FindConVar("l4d_ready_cfg_name");

    if (g_hConfigurationName != null)
        g_hConfigurationName.GetString(g_sConfigurationName, sizeof(g_sConfigurationName));

    if (strlen(g_sConfigurationName) > 0)
        command.SetString("name", g_sConfigurationName);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/configuration");
    
    request.Put(command, DoNothing);
}

void SendRound()
{
    if (g_bInTransition)
        return;

    JSONObject command = new JSONObject();

    g_iTankPercent = GetTankPercent();
    g_iWitchPercent = GetWitchPercent();

    command.SetBool("isInReady", GetIsInReady());

    if (g_bPauseIsAvailable)
        command.SetBool("isInPause", IsInPause());

    command.SetBool("inSecondHalfOfRound", GameRules_GetProp("m_bInSecondHalfOfRound") ? true : false);
    command.SetInt("maxChapterProgressPoints", L4D_GetVersusMaxCompletionScore());
    command.SetFloat("tankPercent", g_iTankPercent / 100.0);
    command.SetFloat("witchPercent", g_iWitchPercent / 100.0);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/round");

    request.Put(command, DoNothing);
}

void SendScoreboard()
{
    if (g_bInTransition)
        return;

    JSONObject command = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");
    bool isInReady = GetIsInReady();
    int bonus = GetBonus();
    int maxBonus = GetMaxBonus();

    command.SetInt("survivorScore", L4D2Direct_GetVSCampaignScore(flipped ? 1 : 0) + L4D_GetTeamScore(flipped ? 2 : 1));
    command.SetInt("infectedScore", L4D2Direct_GetVSCampaignScore(flipped ? 0 : 1) + L4D_GetTeamScore(flipped ? 1 : 2));
    command.SetInt("bonus", isInReady ? maxBonus : bonus);
    command.SetInt("maxBonus", maxBonus);
    command.SetFloat("currentProgress", isInReady ? 0.0 : (GetCurrentProgress() / 100.0));
    command.SetInt("currentProgressPoints", isInReady ? 0 : L4D_GetTeamScore(flipped ? 2 : 1));
    command.SetBool("isTankInPlay", IsTankInPlay());
    command.SetBool("tankIsDead", g_bTankIsDead);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/scoreboard");

    request.Put(command, DoNothing);
}

void SendPlayers()
{
    if (g_bInTransition)
        return;

    JSONObject command = new JSONObject();

    JSONArray survivors = new JSONArray();
    JSONArray infecteds = new JSONArray();
    JSONArray spectators = new JSONArray();

    char communityId[25];
    char name[MAX_NAME_LENGTH];

    bool isInReady = GetIsInReady();

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

        player.SetBool("isAdmin", CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN));

        if (team == L4D2_TEAM_SURVIVOR || team == L4D2_TEAM_INFECTED)
            player.SetFloat("latency", GetClientLatency(client, NetFlow_Both));

        if (team == L4D2_TEAM_SURVIVOR)
        {
            player.SetInt("character", IdentifySurvivor(client));

            bool isPlayerAlive = IsPlayerAlive(client);

            if (isPlayerAlive)
            {
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

                if (!IsTankInPlay())
                {
                    float progress = GetSurvivorProgress(client);
                    if (progress > g_fSurvivorProgress[client])
                        g_fSurvivorProgress[client] = progress;
                }
            }

            player.SetBool("isPlayerAlive", isPlayerAlive);
            player.SetFloat("progress", isInReady ? 0.0 : g_fSurvivorProgress[client]);

            survivors.Push(player);
        }

        if (team == L4D2_TEAM_INFECTED)
        {
            bool isInfectedGhost = IsInfectedGhost(client);
            bool isPlayerAlive = IsPlayerAlive(client);

            if (isInfectedGhost || isPlayerAlive)
            {
                player.SetInt("type", GetInfectedClass(client));
                player.SetInt("health", GetClientHealth(client));
                player.SetInt("maxHealth", GetEntProp(client, Prop_Data, "m_iMaxHealth"));
            }

            player.SetInt("damage", g_iInfectedDamage[client]);
            player.SetBool("isInfectedGhost", isInfectedGhost);
            player.SetBool("isPlayerAlive", isPlayerAlive);

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

void CheckForNewExternalMessages()
{
    if (g_bInTransition)
        return;

    char path[128] = "/api/external-chat";
    
    if (strlen(g_sLastMessage) != 0)
        FormatEx(path, sizeof(path), "%s?after=%s", path, g_sLastMessage);

    HTTPRequest request = BuildHTTPRequest(path);

    request.Get(CheckForNewExternalMessagesResponse);
}

void CheckForNewExternalMessagesResponse(HTTPResponse httpResponse, any value)
{
    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONArray response = view_as<JSONArray>(httpResponse.Data);

    for (int i = 0; i < response.Length; i++)
    {
        JSONObject message = view_as<JSONObject>(response.Get(i));

        message.GetString("ticks", g_sLastMessage, sizeof(g_sLastMessage));

        char steamId[64];
        message.GetString("steamId", steamId, sizeof(steamId));

        char profileUrl[256];
        message.GetString("profileUrl", profileUrl, sizeof(profileUrl));

        char name[64];
        message.GetString("name", name, sizeof(name));

        char text[250];
        message.GetString("text", text, sizeof(text));

        CPrintToChatAll("{default}(External) {orange}%s{default} : %s", name, text);

        PrintToConsoleAll("[External] %s (%s): %s", name, steamId, text);
        PrintToConsoleAll(profileUrl);
    }
}

void CheckForNewServerCommands()
{
    if (g_bInTransition)
        return;

    HTTPRequest request = BuildHTTPRequest("/api/game-info/server-command/dequeue");

    request.Get(CheckForNewServerCommandsResponse);
}

void CheckForNewServerCommandsResponse(HTTPResponse httpResponse, any value)
{
    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONObject response = view_as<JSONObject>(httpResponse.Data);

    char fullCommand[256];
    response.GetString("fullCommand", fullCommand, sizeof(fullCommand));

    ServerCommand(fullCommand);
}

void DoNothing(HTTPResponse httpResponse, any value)
{
}

HTTPRequest BuildHTTPRequest(char[] path)
{
    char url[255];
    GetConVarString(g_hUrl, url, sizeof(url));
    StrCat(url, sizeof(url), path);

    char secretKey[100];
    GetConVarString(g_hSecretKey, secretKey, sizeof(secretKey));

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Authorization", secretKey);

    return request;
}

void ClearInfectedDamage()
{
    for (int i = 1; i <= MaxClients; i++)
        g_iInfectedDamage[i] = 0;
}

void ClearSurvivorProgress()
{
    for (int i = 1; i <= MaxClients; i++)
        g_fSurvivorProgress[i] = 0.0;
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

int GetCurrentProgress()
{
	return RoundToNearest(GetBossProximity() * 100.0);
}

float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVersusBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance();

	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == L4D2_TEAM_SURVIVOR) {
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}

	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

bool GetIsInReady()
{
    if (!g_bReadyUpIsAvailable)
        return false;

    return IsInReady();
}

int GetTankPercent()
{
    if (g_bL4D2BossPercentsAvailable)
        return GetStoredTankPercent();

    return GetRoundTankFlow();
}

int GetWitchPercent()
{
    if (g_bL4D2BossPercentsAvailable)
        return GetStoredWitchPercent();

    return GetRoundWitchFlow();
}

int GetRoundTankFlow()
{
	return RoundToNearest(L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()) + g_hVersusBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance());
}

int GetRoundWitchFlow()
{
	return RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(InSecondHalfOfRound()) + g_hVersusBossBuffer.FloatValue / L4D2Direct_GetMapMaxFlowDistance());
}

int GetBonus()
{
    if (!g_bHybridScoremodIsAvailable)
        return 0;

    return SMPlus_GetHealthBonus() + SMPlus_GetDamageBonus() + SMPlus_GetPillsBonus();
}

int GetMaxBonus()
{
    if (!g_bHybridScoremodIsAvailable)
        return 0;

    return SMPlus_GetMaxHealthBonus() + SMPlus_GetMaxDamageBonus() + SMPlus_GetMaxPillsBonus();
}

float Max(float a, float b) {
    return (a > b) ? a : b;
}

float Min(float a, float b) {
    return (a < b) ? a : b;
}