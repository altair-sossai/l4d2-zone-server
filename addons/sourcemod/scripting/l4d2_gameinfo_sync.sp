#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <ripext>
#include <colors>

#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

#undef REQUIRE_PLUGIN
#include <pause>
#include <readyup>
#include <l4d2_boss_percents>
#include <l4d2_hybrid_scoremod>
#include <l4d2_skill_detect>

#define GAMEINFO_HTTP_CONNECT_TIMEOUT 3
#define GAMEINFO_HTTP_TIMEOUT 5

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
    g_hVersusBossBuffer,
    g_hRelatedAccountsChat,
    g_hBoomerVomitMinSurvivors,
    g_hSpecialClearMaxSeconds;

char
    g_sConfigurationName[64],
    g_sLastMessage[32],
    g_sUrl[255],
    g_sSecretKey[100],
    g_sCommunityId[MAXPLAYERS + 1][25];

bool 
    g_bReadyUpIsAvailable = false,
    g_bPauseIsAvailable = false,
    g_bL4D2BossPercentsAvailable = false,
    g_bHybridScoremodIsAvailable = false,
    g_bInTransition = false,
    g_bRoundOver = false,
    g_bTankIsDead = false,
    g_bConfigurationRequestPending = false,
    g_bRoundRequestPending = false,
    g_bScoreboardRequestPending = false,
    g_bPlayersRequestPending = false,
    g_bExternalMessagesRequestPending = false,
    g_bServerCommandsRequestPending = false;

int 
    g_iInfectedDamage[MAXPLAYERS + 1],
    g_iTankPercent,
    g_iWitchPercent;

float
    g_fSurvivorProgress[MAXPLAYERS + 1],
    g_fMapMaxFlowDistance = 0.0;

public void OnPluginStart()
{
    LoadTranslations("l4d2_gameinfo_sync.phrases");

    g_hVersusBossBuffer = FindConVar("versus_boss_buffer");

    g_hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    g_hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);
    g_hRelatedAccountsChat = CreateConVar("gameinfo_related_accounts_chat", "1", "Announce related accounts (same IP) in chat", _, true, 0.0, true, 1.0);
    g_hBoomerVomitMinSurvivors = CreateConVar("gameinfo_boomer_vomit_min_survivors", "3", "Minimum number of survivors hit to report a boomer vomit event", _, true, 1.0);
    g_hSpecialClearMaxSeconds = CreateConVar("gameinfo_special_clear_max_seconds", "1.5", "Maximum clear time in seconds to report a special clear (insta-clear) event", _, true, 0.0);

    g_hUrl.AddChangeHook(OnCredentialsChanged);
    g_hSecretKey.AddChangeHook(OnCredentialsChanged);

    RefreshCredentials();

    AddCommandListener(Say_Callback, "say");
    AddCommandListener(Say_Callback, "say_team");

    HookEvent("round_start", RoundStart_Event);
    HookEvent("player_hurt", PlayerHurt_Event);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("player_disconnect", PlayerDisconnect_Event);
    HookEvent("player_bot_replace", PlayerBotReplace_Event);

    CreateTimer(5.0, SyncData_Timer, _, TIMER_REPEAT);

    ClearInfectedDamage();
    ClearSurvivorProgress();
}

public void OnConfigsExecuted()
{
    RefreshCredentials();
}

public void OnMapStart()
{
    g_fMapMaxFlowDistance = 0.0;
}

public void OnMapEnd()
{
    g_fMapMaxFlowDistance = 0.0;
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

public void OnClientPostAdminCheck(int client)
{
    if (!IsFakeClient(client))
    {
        char communityId[25];
        GetCommunityId(client, communityId, sizeof(communityId));
    }

    SendPlayerConnectionInfo(client);
}

public void OnClientDisconnect(int client)
{
    g_sCommunityId[client][0] = '\0';
}

public void OnRoundIsLive()
{
    g_bInTransition = false;
    g_bTankIsDead = false;

    ClearInfectedDamage();
    ClearSurvivorProgress();
    CreateTimer(2.0, OnRoundIsLive_Timer);

    SendRoundLive();
}

public void OnPause()
{
    SendRound();
    SendPause(true);
}

public void OnUnpause()
{
    SendRound();
    SendPause(false);
}

public void L4D2_OnEndVersusModeRound_Post()
{
    g_bRoundOver = true;

    SendRound();
    SendScoreboard();
    SendPlayers();
    SendRoundEnded();

    CreateTimer(2.5, L4D2_OnEndVersusModeRound_Post_Timer);
}

public void L4D_OnLeaveStasis(int tank)
{
    if (g_bInTransition || GetIsInReady())
        return;

    if (IsFakeClient(tank))
        return;

    SendTankSpawned(tank);
}

public void OnSkeet(int survivor, int hunter)
{
    SendSkeet(survivor, hunter, "Shotgun");
}

public void OnSkeetMelee(int survivor, int hunter)
{
    SendSkeet(survivor, hunter, "Melee");
}

public void OnSkeetGL(int survivor, int hunter)
{
    SendSkeet(survivor, hunter, "Grenade");
}

public void OnSkeetSniper(int survivor, int hunter)
{
    SendSkeet(survivor, hunter, "Sniper");
}

public void OnSkeetHurt(int survivor, int hunter, int damage, bool isOverkill)
{
    SendSkeetHurt(survivor, hunter, damage, isOverkill, "Shotgun");
}

public void OnSkeetMeleeHurt(int survivor, int hunter, int damage, bool isOverkill)
{
    SendSkeetHurt(survivor, hunter, damage, isOverkill, "Melee");
}

public void OnSkeetSniperHurt(int survivor, int hunter, int damage, bool isOverkill)
{
    SendSkeetHurt(survivor, hunter, damage, isOverkill, "Sniper");
}

public void OnChargerLevel(int survivor, int charger)
{
    JSONObject event = BuildEvent("chargerLevel", survivor);
    SetPlayer(event, "charger", charger);
    SendEvent(event);
}

public void OnChargerLevelHurt(int survivor, int charger, int damage)
{
    JSONObject event = BuildEvent("chargerLevelHurt", survivor);
    SetPlayer(event, "charger", charger);
    event.SetInt("damage", damage);
    SendEvent(event);
}

public void OnWitchCrown(int survivor, int damage)
{
    JSONObject event = BuildEvent("witchCrown", survivor);
    event.SetInt("damage", damage);
    SendEvent(event);
}

public void OnWitchCrownHurt(int survivor, int damage, int chipdamage)
{
    JSONObject event = BuildEvent("witchCrownHurt", survivor);
    event.SetInt("damage", damage);
    event.SetInt("chipDamage", chipdamage);
    SendEvent(event);
}

public void OnTongueCut(int survivor, int smoker)
{
    JSONObject event = BuildEvent("tongueCut", survivor);
    SetPlayer(event, "smoker", smoker);
    SendEvent(event);
}

public void OnSmokerSelfClear(int survivor, int smoker, bool withShove)
{
    JSONObject event = BuildEvent("smokerSelfClear", survivor);
    SetPlayer(event, "smoker", smoker);
    event.SetBool("withShove", withShove);
    SendEvent(event);
}

public void OnTankRockSkeeted(int survivor, int tank)
{
    JSONObject event = BuildEvent("tankRockSkeeted", survivor);
    SetPlayer(event, "tank", tank);
    SendEvent(event);
}

public void OnTankRockEaten(int tank, int survivor)
{
    JSONObject event = BuildEvent("tankRockEaten", tank);
    SetPlayer(event, "victim", survivor);
    SendEvent(event);
}

public void OnHunterHighPounce(int hunter, int survivor, int actualDamage, float calculatedDamage, float height, bool reportedHigh)
{
    if (!reportedHigh)
        return;

    JSONObject event = BuildEvent("hunterHighPounce", hunter);
    SetPlayer(event, "victim", survivor);
    event.SetFloat("calculatedDamage", calculatedDamage);
    event.SetFloat("height", height);
    SendEvent(event);
}

public void OnDeathCharge(int charger, int survivor, float height, float distance, bool wasCarried)
{
    JSONObject event = BuildEvent("deathCharge", charger);
    SetPlayer(event, "victim", survivor);
    event.SetFloat("height", height);
    event.SetFloat("distance", distance);
    event.SetBool("wasCarried", wasCarried);
    SendEvent(event);
}

public void OnSpecialClear(int clearer, int pinner, int pinvictim, int zombieClass, float timeA, float timeB, bool withShove)
{
    float clearTime = (zombieClass == L4D2Infected_Smoker || zombieClass == L4D2Infected_Charger) ? timeB : timeA;

    if (clearTime < 0.0 || clearTime > g_hSpecialClearMaxSeconds.FloatValue)
        return;

    JSONObject event = BuildEvent("specialClear", clearer);
    SetPlayer(event, "pinner", pinner);
    SetPlayer(event, "pinVictim", pinvictim);
    event.SetInt("zombieClass", zombieClass);
    event.SetFloat("clearTime", clearTime);
    event.SetBool("withShove", withShove);
    SendEvent(event);
}

public void OnBoomerVomitLanded(int boomer, int amount)
{
    if (amount < g_hBoomerVomitMinSurvivors.IntValue)
        return;

    JSONObject event = BuildEvent("boomerVomitLanded", boomer);
    event.SetInt("amount", amount);
    SendEvent(event);
}

public void OnCarAlarmTriggered(int survivor, int infected, CarAlarmTriggerReason reason)
{
    JSONObject event = BuildEvent("carAlarmTriggered", survivor);
    SetPlayer(event, "infected", infected);
    event.SetInt("reason", view_as<int>(reason));
    SendEvent(event);
}

Action Say_Callback(int client, char[] command, int args)
{
    if (args == 0)
        return Plugin_Continue;

    if (!IsValidClient(client))
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
    GetCommunityId(client, communityId, sizeof(communityId));
    jObject.SetString("communityId", communityId);

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    jObject.SetString("name", name);

    jObject.SetBool("isAdmin", CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN));

    jObject.SetString("message", message);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/messages");
    
    request.Put(jObject, DoNothing, jObject);

    return Plugin_Continue; 
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    g_fMapMaxFlowDistance = 0.0;
    g_bRoundOver = false;
    g_bTankIsDead = false;

    ClearInfectedDamage();
    ClearSurvivorProgress();
    CreateTimer(5.0, RoundStart_Timer);
}

void PlayerHurt_Event(Handle event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!IsValidClient(attacker) || GetClientTeam(attacker) != L4D2Team_Infected)
	    return;
	
	g_iInfectedDamage[attacker] += GetEventInt(event, "dmg_health");
}

void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    int victim = GetClientOfUserId(hEvent.GetInt("userid"));

    if (!IsValidClient(victim))
        return;

    int team = GetClientTeam(victim);

    if (team == L4D2Team_Survivor)
    {
        SendPlayerDeath(victim);
        return;
    }

    if (team == L4D2Team_Infected && !g_bTankIsDead && GetEntProp(victim, Prop_Send, "m_zombieClass") == L4D2Infected_Tank)
    {
        g_bTankIsDead = true;
        SendTankDied(victim);
    }
}

void PlayerBotReplace_Event(Event event, const char[] name, bool dontBroadcast)
{
    int newTank = GetClientOfUserId(event.GetInt("bot"));

    if (!IsValidClient(newTank))
        return;

    if (GetClientTeam(newTank) != L4D2Team_Infected)
        return;

    if (GetEntProp(newTank, Prop_Send, "m_zombieClass") != L4D2Infected_Tank)
        return;

    int formerTank = GetClientOfUserId(event.GetInt("player"));

    SendTankBecameBot(formerTank);
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

void SendPlayerConnectionInfo(int client)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    char communityId[25];
    if (!GetCommunityId(client, communityId, sizeof(communityId)))
        return;

    char ipAddress[46];
    if (!GetClientIP(client, ipAddress, sizeof(ipAddress)))
        return;

    JSONObject connectionInfo = new JSONObject();

    connectionInfo.SetString("communityId", communityId);
    connectionInfo.SetString("ipAddress", ipAddress);

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    connectionInfo.SetString("name", name);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/player-connection-info");

    request.Post(connectionInfo, SendPlayerConnectionInfoResponse, GetClientUserId(client));

    delete connectionInfo;
}

void SendConfiguration()
{
    if (g_bInTransition || g_bConfigurationRequestPending)
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
    
    g_bConfigurationRequestPending = true;

    request.Put(command, SendConfigurationResponse, command);
}

void SendRound()
{
    if (g_bInTransition || g_bRoundRequestPending)
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

    g_bRoundRequestPending = true;

    request.Put(command, SendRoundResponse, command);
}

void SendScoreboard()
{
    if (g_bInTransition || g_bScoreboardRequestPending)
        return;

    JSONObject command = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");
    bool isInReady = GetIsInReady();
    int bonus = GetBonus();
    int maxBonus = GetMaxBonus();

    command.SetInt("survivorScore", GetTeamTotalScore(flipped ? 1 : 0, flipped ? 2 : 1));
    command.SetInt("infectedScore", GetTeamTotalScore(flipped ? 0 : 1, flipped ? 1 : 2));
    command.SetInt("bonus", isInReady ? maxBonus : bonus);
    command.SetInt("maxBonus", maxBonus);
    command.SetFloat("currentProgress", isInReady ? 0.0 : (GetCurrentProgress() / 100.0));
    command.SetInt("currentProgressPoints", isInReady ? 0 : L4D_GetTeamScore(flipped ? 2 : 1));
    command.SetBool("isTankInPlay", IsTankInPlay());
    command.SetBool("tankIsDead", g_bTankIsDead);

    HTTPRequest request = BuildHTTPRequest("/api/game-info/scoreboard");

    g_bScoreboardRequestPending = true;

    request.Put(command, SendScoreboardResponse, command);
}

void SendPlayers()
{
    if (g_bInTransition || g_bPlayersRequestPending)
        return;

    JSONObject command = new JSONObject();

    JSONArray survivors = new JSONArray();
    JSONArray infecteds = new JSONArray();
    JSONArray spectators = new JSONArray();

    char communityId[25];
    char name[MAX_NAME_LENGTH];

    bool isInReady = GetIsInReady();
    bool isTankInPlay = IsTankInPlay();

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;

        int team = GetClientTeam(client);
        if (team != L4D2Team_Spectator && team != L4D2Team_Survivor && team != L4D2Team_Infected)
            continue;

        JSONObject player = new JSONObject();

        GetCommunityId(client, communityId, sizeof(communityId));
        player.SetString("communityId", communityId);

        GetClientName(client, name, sizeof(name));
        player.SetString("name", name);

        player.SetBool("isAdmin", CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN));

        if (team == L4D2Team_Survivor || team == L4D2Team_Infected)
            player.SetFloat("latency", GetClientLatency(client, NetFlow_Both));

        if (team == L4D2Team_Survivor)
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

                if (!isTankInPlay)
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

        if (team == L4D2Team_Infected)
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
        
        if (team == L4D2Team_Spectator)
            spectators.Push(player);

        delete player;
    }

    command.Set("survivors", survivors);
    command.Set("infecteds", infecteds);
    command.Set("spectators", spectators);

    delete survivors;
    delete infecteds;
    delete spectators;

    HTTPRequest request = BuildHTTPRequest("/api/game-info/players");

    g_bPlayersRequestPending = true;

    request.Put(command, SendPlayersResponse, command);
}

void SendSkeet(int survivor, int hunter, const char[] skeetType)
{
    JSONObject event = BuildEvent("skeet", survivor);
    SetPlayer(event, "hunter", hunter);
    event.SetString("skeetType", skeetType);
    event.SetBool("isTeamSkeet", survivor == -2);
    SendEvent(event);
}

void SendSkeetHurt(int survivor, int hunter, int damage, bool isOverkill, const char[] skeetType)
{
    JSONObject event = BuildEvent("skeetHurt", survivor);
    SetPlayer(event, "hunter", hunter);
    event.SetString("skeetType", skeetType);
    event.SetInt("damage", damage);
    event.SetBool("isOverkill", isOverkill);
    SendEvent(event);
}

void SendRoundLive()
{
    JSONObject event = BuildEvent("roundLive", 0);
    event.SetBool("secondHalf", GameRules_GetProp("m_bInSecondHalfOfRound") ? true : false);
    SendEvent(event);
}

void SendRoundEnded()
{
    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    JSONObject event = BuildEvent("roundEnded", 0);
    event.SetInt("survivorScore", GetTeamTotalScore(flipped ? 1 : 0, flipped ? 2 : 1));
    event.SetInt("infectedScore", GetTeamTotalScore(flipped ? 0 : 1, flipped ? 1 : 2));
    SendEvent(event);
}

void SendPause(bool paused)
{
    JSONObject event = BuildEvent("pause", 0);
    event.SetBool("paused", paused);
    SendEvent(event);
}

void SendTankSpawned(int tank)
{
    if (!IsValidClient(tank))
        return;

    JSONObject event = BuildEvent("tankSpawned", tank);
    SendEvent(event);
}

void SendTankDied(int tank)
{
    if (g_bInTransition || GetIsInReady())
        return;

    if (!IsValidClient(tank))
        return;

    JSONObject event = BuildEvent("tankDied", tank);
    SendEvent(event);
}

void SendTankBecameBot(int formerTank)
{
    if (g_bInTransition || g_bRoundOver || GetIsInReady())
        return;

    JSONObject event = BuildEvent("tankBecameBot", formerTank);
    SendEvent(event);
}

void SendPlayerDeath(int survivor)
{
    if (g_bInTransition || GetIsInReady())
        return;

    JSONObject event = BuildEvent("playerDeath", survivor);
    SendEvent(event);
}

void SendEvent(JSONObject event)
{
    if (strlen(g_sUrl) == 0)
    {
        delete event;
        return;
    }

    HTTPRequest request = BuildHTTPRequest("/api/game-info/events");

    request.Post(event, DoNothing, event);
}

void CheckForNewExternalMessages()
{
    if (g_bInTransition || g_bExternalMessagesRequestPending)
        return;

    char path[128] = "/api/external-chat";
    
    if (strlen(g_sLastMessage) != 0)
        FormatEx(path, sizeof(path), "%s?after=%s", path, g_sLastMessage);

    HTTPRequest request = BuildHTTPRequest(path);

    g_bExternalMessagesRequestPending = true;

    request.Get(CheckForNewExternalMessagesResponse);
}

void CheckForNewExternalMessagesResponse(HTTPResponse httpResponse, any value)
{
    g_bExternalMessagesRequestPending = false;

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

        CPrintToChatAll("%t", "ExternalChatMessage", name, text);

        PrintToConsoleAll("%t", "ExternalConsoleMessage", name, steamId, text);
        PrintToConsoleAll(profileUrl);

        delete message;
    }
}

void CheckForNewServerCommands()
{
    if (g_bInTransition || g_bServerCommandsRequestPending)
        return;

    HTTPRequest request = BuildHTTPRequest("/api/game-info/server-command/dequeue");

    g_bServerCommandsRequestPending = true;

    request.Get(CheckForNewServerCommandsResponse);
}

void CheckForNewServerCommandsResponse(HTTPResponse httpResponse, any value)
{
    g_bServerCommandsRequestPending = false;

    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONObject response = view_as<JSONObject>(httpResponse.Data);

    char fullCommand[256];
    response.GetString("fullCommand", fullCommand, sizeof(fullCommand));

    ServerCommand(fullCommand);
}

void SendPlayerConnectionInfoResponse(HTTPResponse httpResponse, any value)
{
    if (httpResponse.Status != HTTPStatus_OK)
        return;

    JSONArray relatedPlayers = view_as<JSONArray>(httpResponse.Data);

    if (relatedPlayers.Length == 0)
        return;

    int client = GetClientOfUserId(value);

    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    JSONObject firstRelatedPlayer = view_as<JSONObject>(relatedPlayers.Get(0));
    char firstRelatedPlayerName[MAX_NAME_LENGTH];
    firstRelatedPlayer.GetString("name", firstRelatedPlayerName, sizeof(firstRelatedPlayerName));
    delete firstRelatedPlayer;

    int additionalAccounts = relatedPlayers.Length - 1;

    if (g_hRelatedAccountsChat.BoolValue)
    {
        if (additionalAccounts == 0)
            CPrintToChatAll("%t", "RelatedAccount", client, firstRelatedPlayerName);
        else if (additionalAccounts == 1)
            CPrintToChatAll("%t", "RelatedAccountOneAdditional", client, firstRelatedPlayerName);
        else
            CPrintToChatAll("%t", "RelatedAccountMultipleAdditional", client, firstRelatedPlayerName, additionalAccounts);
    }

    PrintToConsoleAll("%t", "RelatedAccountsConsoleHeader", client);

    for (int i = 0; i < relatedPlayers.Length; i++)
    {
        JSONObject relatedPlayer = view_as<JSONObject>(relatedPlayers.Get(i));

        char relatedPlayerName[MAX_NAME_LENGTH];
        relatedPlayer.GetString("name", relatedPlayerName, sizeof(relatedPlayerName));

        char communityId[25];
        relatedPlayer.GetString("communityId", communityId, sizeof(communityId));

        char steamId[64];
        steamId[0] = '\0';
        relatedPlayer.GetString("steamId", steamId, sizeof(steamId));

        char profileUrl[256];
        profileUrl[0] = '\0';
        relatedPlayer.GetString("profileUrl", profileUrl, sizeof(profileUrl));

        PrintToConsoleAll("[IP] %s | %s | %s", relatedPlayerName, communityId, steamId);
        PrintToConsoleAll("[IP] %s", profileUrl);

        delete relatedPlayer;
    }
}

void SendConfigurationResponse(HTTPResponse httpResponse, any value)
{
    g_bConfigurationRequestPending = false;

    delete view_as<JSONObject>(value);
}

void SendRoundResponse(HTTPResponse httpResponse, any value)
{
    g_bRoundRequestPending = false;

    delete view_as<JSONObject>(value);
}

void SendScoreboardResponse(HTTPResponse httpResponse, any value)
{
    g_bScoreboardRequestPending = false;

    delete view_as<JSONObject>(value);
}

void SendPlayersResponse(HTTPResponse httpResponse, any value)
{
    g_bPlayersRequestPending = false;

    delete view_as<JSONObject>(value);
}

void DoNothing(HTTPResponse httpResponse, any value)
{
    delete view_as<JSONObject>(value);
}

void RefreshCredentials()
{
    g_hUrl.GetString(g_sUrl, sizeof(g_sUrl));
    g_hSecretKey.GetString(g_sSecretKey, sizeof(g_sSecretKey));
}

void OnCredentialsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    RefreshCredentials();
}

JSONObject BuildEvent(const char[] type, int actor)
{
    JSONObject event = new JSONObject();
    event.SetString("type", type);
    SetPlayer(event, "actor", actor);

    return event;
}

void SetPlayer(JSONObject event, const char[] key, int client)
{
    JSONObject player = BuildPlayer(client);
    if (player == null)
        return;

    event.Set(key, player);

    delete player;
}

JSONObject BuildPlayer(int client)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return null;

    JSONObject player = new JSONObject();
    bool isBot = IsFakeClient(client);

    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    player.SetString("name", name);
    player.SetBool("isBot", isBot);

    if (!isBot)
    {
        char communityId[25];
        if (GetCommunityId(client, communityId, sizeof(communityId)))
            player.SetString("communityId", communityId);
    }

    return player;
}

HTTPRequest BuildHTTPRequest(char[] path)
{
    char url[255];
    strcopy(url, sizeof(url), g_sUrl);
    StrCat(url, sizeof(url), path);

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Authorization", g_sSecretKey);
    request.ConnectTimeout = GAMEINFO_HTTP_CONNECT_TIMEOUT;
    request.Timeout = GAMEINFO_HTTP_TIMEOUT;

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
        return Max(0.0, Min(L4D2Direct_GetTerrorNavAreaFlow(navArea) / GetMapMaxFlowDistanceCached(), 1.0));

    return 0.0;
}

int GetCurrentProgress()
{
	return RoundToNearest(GetBossProximity() * 100.0);
}

float GetBossProximity()
{
	float proximity = GetMaxSurvivorCompletion() + g_hVersusBossBuffer.FloatValue / GetMapMaxFlowDistanceCached();

	return (proximity > 1.0) ? 1.0 : proximity;
}

float GetMaxSurvivorCompletion()
{
	float flow = 0.0, tmp_flow = 0.0, origin[3];
	Address pNavArea;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == L4D2Team_Survivor) {
			GetClientAbsOrigin(i, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea != Address_Null) {
				tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				flow = (flow > tmp_flow) ? flow : tmp_flow;
			}
		}
	}

	return (flow / GetMapMaxFlowDistanceCached());
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
	return RoundToNearest(L4D2Direct_GetVSTankFlowPercent(InSecondHalfOfRound()) + g_hVersusBossBuffer.FloatValue / GetMapMaxFlowDistanceCached());
}

int GetRoundWitchFlow()
{
	return RoundToNearest(L4D2Direct_GetVSWitchFlowPercent(InSecondHalfOfRound()) + g_hVersusBossBuffer.FloatValue / GetMapMaxFlowDistanceCached());
}

float GetMapMaxFlowDistanceCached()
{
    if (g_fMapMaxFlowDistance <= 0.0)
        g_fMapMaxFlowDistance = L4D2Direct_GetMapMaxFlowDistance();

    return g_fMapMaxFlowDistance;
}

int GetTeamTotalScore(int campaignTeam, int logicalTeam)
{
    int score = L4D2Direct_GetVSCampaignScore(campaignTeam);

    if (g_bRoundOver)
        return score;

    int mapScore = L4D_GetTeamScore(logicalTeam);

    if (mapScore > 0)
        score += mapScore;

    return score;
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

bool GetCommunityId(int client, char[] buffer, int size)
{
    if (g_sCommunityId[client][0] != '\0')
    {
        strcopy(buffer, size, g_sCommunityId[client]);
        return true;
    }

    if (!GetClientAuthId(client, AuthId_SteamID64, buffer, size))
        return false;

    strcopy(g_sCommunityId[client], sizeof(g_sCommunityId[]), buffer);

    return true;
}

bool IsValidClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client);
}

float Max(float a, float b) {
    return (a > b) ? a : b;
}

float Min(float a, float b) {
    return (a < b) ? a : b;
}
