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
    hSecretKey;

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    CreateTimer(10.0, SendGameInfoTick, _, TIMER_REPEAT);
}

Action SendGameInfoTick(Handle handle)
{
    int areTeamsFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
    int survivorScore = L4D2Direct_GetVSCampaignScore(areTeamsFlipped ? 1 : 0);
    int infectedScore = L4D2Direct_GetVSCampaignScore(areTeamsFlipped ? 0 : 1);

    JSONObject command = new JSONObject();

    command.SetInt("areTeamsFlipped", areTeamsFlipped);
    command.SetInt("survivorScore", survivorScore);
    command.SetInt("infectedScore", infectedScore);

    HTTPRequest request = BuildHTTPRequest("/api/game-info");
    request.Put(command, DoNothing);

    return Plugin_Handled;
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