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

JSONObject 
    ConfigurationCommand;

HTTPRequest
    ConfigurationRequest;

char ConfigurationName[64];

public void OnPluginStart()
{
    hUrl = CreateConVar("gameinfo_url", "", "Game Info API URL", FCVAR_PROTECTED);
    hSecretKey = CreateConVar("gameinfo_secret", "", "Game Info API Secret Key", FCVAR_PROTECTED);

    SendConfiguration();
}

void SendConfiguration()
{
    if (ConfigurationCommand == null)
        ConfigurationCommand = new JSONObject();

    ConfigurationCommand.SetInt("teamSize", GetConVarInt(FindConVar("survivor_limit")));

    if (hConfigurationName == null)
        hConfigurationName = FindConVar("l4d_ready_cfg_name");

    if (hConfigurationName != null)
        hConfigurationName.GetString(ConfigurationName, sizeof(ConfigurationName));

    if (strlen(ConfigurationName) > 0)
        ConfigurationCommand.SetString("name", ConfigurationName);

    if (ConfigurationRequest == null)
        ConfigurationRequest = BuildHTTPRequest("/api/game-info/configuration");
    
    ConfigurationRequest.Put(ConfigurationCommand, DoNothing);
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