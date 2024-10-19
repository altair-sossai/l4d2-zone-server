#pragma semicolon 1
#pragma newdecls required

#include <colors>
#include <sourcemod>
#include <readyup>
#include <left4dhooks>

#define L4D2_TEAM_SURVIVOR 2
#define L4D2_TEAM_INFECTED 3

ArrayList h_Queue;

enum struct Player
{
    char steamId[64];
    float priority;
}

public Plugin myinfo =
{
	name = "L4D2 - Queue",
	author = "Altair Sossai",
	description = "Arranges players in a queue, showing who are the next players who should play",
	version = "1.0.0",
	url = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
	h_Queue = new ArrayList(sizeof(Player));

	RegConsoleCmd("sm_fila", PrintQueueCmd);
	RegConsoleCmd("sm_queue", PrintQueueCmd);
}

public Action PrintQueueCmd(int client, int args)
{
	PrintQueue(client);

	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	Enqueue(client);
}

public void OnRoundIsLive()
{
	RequeuePlayers();
}

public void L4D2_OnEndVersusModeRound_Post(int client)
{
	UnqueueAllDisconnected();
	RequeuePlayers();
	PrintQueue(0);
}

void Enqueue(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;

	char steamId[64];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

	if (strlen(steamId) == 0 || StrEqual(steamId, "BOT"))
		return;

	Player player;

	for (int i = 0; i < h_Queue.Length; i++)
	{
		h_Queue.GetArray(i, player);

		if (StrEqual(player.steamId, steamId))
			return;
	}

	strcopy(player.steamId, sizeof(player.steamId), steamId);
	player.priority = GetEngineTime();

	h_Queue.PushArray(player);

	SortQueue();
}

void RequeuePlayers()
{
	Player player;

	bool survivorsAreWinning = SurvivorsAreWinning();
	bool infectedAreWinning = !survivorsAreWinning;

	for (int i = 0; i < h_Queue.Length; i++)
	{
		h_Queue.GetArray(i, player);

		int client = GetClientUsingSteamId(player.steamId);
		if (client == -1)
			continue;

		int team = GetClientTeam(client);
		if (team != L4D2_TEAM_SURVIVOR && team != L4D2_TEAM_INFECTED)
			continue;

		if (survivorsAreWinning && team == L4D2_TEAM_SURVIVOR)
			player.priority = 0.0;
		else if (infectedAreWinning && team == L4D2_TEAM_INFECTED)
			player.priority = 0.0;
		else
			player.priority = GetEngineTime();

		h_Queue.SetArray(i, player);
	}

	SortQueue();
}

void UnqueueAllDisconnected()
{
	Player player;
	
	for (int i = 0; i < h_Queue.Length; )
	{
		h_Queue.GetArray(i, player);

		if (GetClientUsingSteamId(player.steamId) != -1)
		{
			i++;
			continue;
		}

		h_Queue.Erase(i);
	}
}

void SortQueue()
{
	h_Queue.SortCustom(SortByPriority);
}

int SortByPriority(int index1, int index2, Handle array, Handle hndl)
{
    Player player1, player2;

    h_Queue.GetArray(index1, player1);
    h_Queue.GetArray(index2, player2);

    if (player1.priority < player2.priority)
        return -1;

    if (player1.priority > player2.priority)
        return 1;

    return 0;
}


int GetClientUsingSteamId(const char[] steamId) 
{
    char current[64];
   
    for (int client = 1; client <= MaxClients; client++) 
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
            continue;
        
        GetClientAuthId(client, AuthId_Steam2, current, sizeof(current));     
        
        if (StrEqual(steamId, current))
            return client;
    }
    
    return -1;
}

void PrintQueue(int target)
{
	if (h_Queue.Length == 0)
		return;

	Player player;
	char color[32];
	char output[512];

	bool isNewGame = IsNewGame();

	for (int i = 0, position = 1; i < h_Queue.Length; i++)
	{
		h_Queue.GetArray(i, player);

		int client = GetClientUsingSteamId(player.steamId);
		if (client == -1)
			continue;

		if (!isNewGame)
		{
			int team = GetClientTeam(client);
			if (team == L4D2_TEAM_SURVIVOR || team == L4D2_TEAM_INFECTED)
				continue;
		}

		if (player.priority == 0)
			strcopy(color, sizeof(color), "{red}");
		else
			strcopy(color, sizeof(color), "{olive}");

		if (position == 1)
			FormatEx(output, sizeof(output), "{orange}Fila: %s%dº {default}%N", color, position, client);
		else
			Format(output, sizeof(output), "%s %s%dº {default}%N", output, color, position, client);

		position++;
	}

	if (target == 0)
		CPrintToChatAll(output);
	else
		CPrintToChat(target, output);
}

bool IsNewGame()
{
	int teamAScore = L4D2Direct_GetVSCampaignScore(0);
	int teamBScore = L4D2Direct_GetVSCampaignScore(1);

	return teamAScore == 0 && teamBScore == 0;
}

bool SurvivorsAreWinning()
{
	int flipped = GameRules_GetProp("m_bAreTeamsFlipped");

	int survivorIndex = flipped ? 1 : 0;
	int infectedIndex = flipped ? 0 : 1;

	int survivorScore = L4D2Direct_GetVSCampaignScore(survivorIndex);
	int infectedScore = L4D2Direct_GetVSCampaignScore(infectedIndex);

	return survivorScore >= infectedScore;
}