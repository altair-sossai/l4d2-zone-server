#pragma semicolon 1
#pragma newdecls required

#include <ripext>
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <readyup>
#include <l4d2util>

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

bool inTransition = false;

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    HookEvent("round_start", RoundStart_Event);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);

    CreateTimer(5.0, Every_5_Seconds_Timer, _, TIMER_REPEAT);
}

public void OnRoundIsLive()
{
    inTransition = false;

    SendPlayers();
}

public void L4D2_OnEndVersusModeRound_Post()
{
    inTransition = true;

    CreateTimer(10.0, L4D2_OnEndVersusModeRound_Post_Timer);
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(5.0, RoundStart_Timer);
}

void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    if (IsInReady())
        return;

    SendPlayers();
}

Action L4D2_OnEndVersusModeRound_Post_Timer(Handle timer)
{
    inTransition = false;

    return Plugin_Continue;
}

Action RoundStart_Timer(Handle timer)
{
    SendConfiguration();
    SendRound();

    return Plugin_Continue;
}

Action Every_5_Seconds_Timer(Handle hTimer)
{
    SendScoreboard();

    return Plugin_Continue;
}

void SendConfiguration()
{
    if (inTransition)
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
    if (inTransition)
        return;

    JSONObject command = new JSONObject();

    command.SetInt("areTeamsFlipped", GameRules_GetProp("m_bAreTeamsFlipped"));
    command.SetInt("maxChapterProgressPoints", L4D_GetVersusMaxCompletionScore());

    HTTPRequest request = BuildHTTPRequest("/api/game-info/round");

    request.Put(command, DoNothing);
}

void SendScoreboard()
{
    if (inTransition)
        return;

    JSONObject command = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    int survivorIndex = flipped ? 1 : 0;
    int infectedIndex = flipped ? 0 : 1;

    command.SetInt("survivorScore", L4D2Direct_GetVSCampaignScore(survivorIndex));
    command.SetInt("infectedScore", L4D2Direct_GetVSCampaignScore(infectedIndex));

    HTTPRequest request = BuildHTTPRequest("/api/game-info/scoreboard");

    request.Put(command, DoNothing);
}

void SendPlayers()
{
    if (inTransition)
        return;

    JSONObject command = new JSONObject();

    JSONArray survivors = new JSONArray();
    JSONArray infecteds = new JSONArray();
    JSONArray spectators = new JSONArray();

    char communityId[25];
    char name[MAX_NAME_LENGTH];

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client))
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
            //player.SetInt("blackAndWhite", 0);
            player.SetBool("incapacitated", IsIncapacitated(client));
            player.SetBool("isPlayerAlive", IsPlayerAlive(client));
            player.SetBool("isFakeClient", IsFakeClient(client));
            //player.SetInt("progress", 0);

            survivors.Push(player);
        }
        
        if (team == L4D2_TEAM_INFECTED)
        {
            player.SetInt("Type", GetInfectedClass(client));
            //player.SetInt("DamageTotal", 0);
            //player.SetInt("CurrentHp", 0);
            //player.SetInt("MaxHp", 0);
            player.SetBool("isInfectedGhost", IsInfectedGhost(client));
            player.SetBool("isPlayerAlive", IsPlayerAlive(client));
            player.SetBool("isFakeClient", IsFakeClient(client));

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