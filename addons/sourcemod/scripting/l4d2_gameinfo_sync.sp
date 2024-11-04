#pragma semicolon 1
#pragma newdecls required

#include <ripext>
#include <sourcemod>
#include <left4dhooks>

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

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    HookEvent("round_start", RoundStart_Event);

    CreateTimer(5.0, Every_5_Seconds_Timer, _, TIMER_REPEAT);
}

void RoundStart_Event(Handle event, const char[] name, bool dontBroadcast)
{
    CreateTimer(5.0, RoundStart_Timer);
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
    JSONObject command = new JSONObject();

    command.SetInt("areTeamsFlipped", GameRules_GetProp("m_bAreTeamsFlipped"));
    command.SetInt("maxChapterProgressPoints", L4D_GetVersusMaxCompletionScore());

    HTTPRequest request = BuildHTTPRequest("/api/game-info/round");

    request.Put(command, DoNothing);
}

void SendScoreboard()
{
    JSONObject command = new JSONObject();

    int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

    int survivorIndex = flipped ? 1 : 0;
    int infectedIndex = flipped ? 0 : 1;

    command.SetInt("survivorScore", L4D2Direct_GetVSCampaignScore(survivorIndex));
    command.SetInt("infectedScore", L4D2Direct_GetVSCampaignScore(infectedIndex));

    HTTPRequest request = BuildHTTPRequest("/api/game-info/scoreboard");

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