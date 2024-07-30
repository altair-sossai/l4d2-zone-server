#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name        = "L4D2 - Localhost",
    author      = "Altair Sossai",
    description = "Open localhost website",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

ConVar hLocalhostUrl;

public void OnPluginStart()
{
    hLocalhostUrl = CreateConVar("localhost_url", "", "URL used to perform local tests", FCVAR_PROTECTED);

    RegConsoleCmd("sm_localhost", LocalHostCmd);
}

Action LocalHostCmd(int client, int args)
{
    char localHostUrl[100];
    GetConVarString(hLocalhostUrl, localHostUrl, sizeof(localHostUrl));

    ShowMOTDPanel(client, "localhost", localHostUrl, MOTDPANEL_TYPE_URL);
    return Plugin_Handled;
}