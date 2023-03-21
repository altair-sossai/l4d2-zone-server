#include <colors>
#include <readyup>

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_CASTER(%1)     (IS_VALID_INGAME(%1) && casterSystemAvailable && IsClientCaster(%1))

ArrayList h_whosHadTank;
ArrayList h_tankVotes;
ArrayList h_tankVoteSteamIds;
ArrayList h_whosVoted;

char queuedTankSteamId[64];
ConVar hTankPrint, hTankDebug;
bool casterSystemAvailable;
bool messageWasDisplayed;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetTankSelection", Native_GetTankSelection);

	return APLRes_Success;
}

public int Native_GetTankSelection(Handle plugin, int numParams) { return getInfectedPlayerBySteamId(queuedTankSteamId); }

public Plugin myinfo = 
{
    name = "L4D2 Tank Control",
    author = "arti",
    description = "Distributes the role of the tank evenly throughout the team",
    version = "0.0.18",
    url = "https://github.com/alexberriman/l4d2-plugins/tree/master/l4d_tank_control"
}

enum L4D2Team
{
    L4D2Team_None = 0,
    L4D2Team_Spectator,
    L4D2Team_Survivor,
    L4D2Team_Infected
}

enum ZClass
{
    ZClass_Smoker = 1,
    ZClass_Boomer = 2,
    ZClass_Hunter = 3,
    ZClass_Spitter = 4,
    ZClass_Jockey = 5,
    ZClass_Charger = 6,
    ZClass_Witch = 7,
    ZClass_Tank = 8
}

public void OnPluginStart()
{
    // Load translations (for targeting player)
    LoadTranslations("common.phrases");
    
    // Event hooks
    HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
    HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
    HookEvent("tank_killed", TankKilled_Event, EventHookMode_PostNoCopy);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    
    // Initialise the tank arrays/data values
    h_whosHadTank = new ArrayList(ByteCountToCells(64));
    h_tankVotes = CreateArray(64);
    h_whosVoted = CreateArray(64);
    h_tankVoteSteamIds = CreateArray(64);

    // Admin commands
    RegAdminCmd("sm_tankshuffle", TankShuffle_Cmd, ADMFLAG_SLAY, "Re-picks at random someone to become tank");
    RegAdminCmd("sm_givetank", GiveTank_Cmd, ADMFLAG_SLAY, "Gives the tank to a selected player");

    // Register the boss commands
    RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank");
    RegConsoleCmd("sm_boss", Tank_Cmd, "Shows who is becoming the tank");
    RegConsoleCmd("sm_witch", Tank_Cmd, "Shows who is becoming the tank");
    RegConsoleCmd("sm_votetank", VoteTank_Cmd, "Vote on who becomes the tank");
    
    // Cvars
    hTankPrint = CreateConVar("tankcontrol_print_all", "0", "Who gets to see who will become the tank? (0 = Infected, 1 = Everyone)");
    hTankDebug = CreateConVar("tankcontrol_debug", "0", "Whether or not to debug to console");
}

public void OnAllPluginsLoaded()
{
	casterSystemAvailable = LibraryExists("caster_system");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "caster_system")) casterSystemAvailable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "caster_system")) casterSystemAvailable = false;
}

/**
 * When a new game starts, reset the tank pool.
 */
 
public void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    messageWasDisplayed = false;

    CreateTimer(10.0, newGame);
    CreateTimer(5.0, showVoteTankMessage);
}

public Action newGame(Handle timer)
{
	int teamAScore = L4D2Direct_GetVSCampaignScore(0);
	int teamBScore = L4D2Direct_GetVSCampaignScore(1);

	// If it's a new game, reset the tank pool
	if (teamAScore == 0 && teamBScore == 0)
	{
		h_whosHadTank.Clear();
		queuedTankSteamId = "";
		clearHandles();
	}

	return Plugin_Stop;
}

public Action showVoteTankMessage(Handle timer)
{
    if(GetInGameInfectedClient() != 0 && !messageWasDisplayed)
    {
        CPrintToChatAll("{default}Use \x04!votetank {default}to choose who will be the tank");
        
        messageWasDisplayed = true;
    }
    else if(!messageWasDisplayed) 
        CreateTimer(2.0, showVoteTankMessage);

    return Plugin_Continue;
}

int GetInGameInfectedClient()
{
    int count = GetClientCount(true);
    for(int client = 1; client <= count; client++ )
        if(IsClientInGame(client) && GetClientTeam(client) == 3)
            return client;

    return 0;
}

/**
 * When the round ends, reset the active tank.
 */
 
public void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    queuedTankSteamId = "";
}

/**
 * When a player leaves the start area, choose a tank and output to all.
 */
 
public void PlayerLeftStartArea_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    chooseTank(0);
    outputTankToAll(0);
}

/**
 * When the queued tank switches teams, choose a new one
 */
 
public void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
	L4D2Team oldTeam = view_as<L4D2Team>(hEvent.GetInt("oldteam"));
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	char tmpSteamId[64];

	if (client && oldTeam == view_as<L4D2Team>(L4D2Team_Infected))
	{
		GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
		if (strcmp(queuedTankSteamId, tmpSteamId) == 0)
		{
			RequestFrame(chooseTank, 0);
			RequestFrame(outputTankToAll, 0);
		}
	}

	L4D2Team team = view_as<L4D2Team>(hEvent.GetInt("team"));
	if (team == view_as<L4D2Team>(L4D2Team_Infected) || oldTeam == view_as<L4D2Team>(L4D2Team_Infected))
    {
        clearHandles();
        if (IsInReady() && NumberOfPlayersInTeams() == 8)
            PrintToInfected("{red}[Tank Vote] {default}Tank votes have been reset, use \x04!votetank {default}to choose the next tank");
    }
}

/**
 * When the tank dies, requeue a player to become tank (for finales)
 */
 
public void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    int zombieClass = 0;
    int victimId = hEvent.GetInt("userid");
    int victim = GetClientOfUserId(victimId);
    
    if (victimId && IsClientInGame(victim)) 
    {
        zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        if (view_as<ZClass>(zombieClass) == ZClass_Tank) 
        {
            if (GetConVarBool(hTankDebug))
            {
                PrintToConsoleAll("[TC] Tank died(1), choosing a new tank");
            }
            chooseTank(0);
        }
    }
}

public void TankKilled_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    if (GetConVarBool(hTankDebug))
    {
        PrintToConsoleAll("[TC] Tank died(2), choosing a new tank");
    }
    chooseTank(0);
}

/**
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
 
public Action Tank_Cmd(int client, int args)
{
    if (!IsClientInGame(client)) 
      return Plugin_Handled;

    int tankClientId;
    char tankClientName[128];
    
    // Only output if we have a queued tank
    if (! strcmp(queuedTankSteamId, ""))
    {
        return Plugin_Handled;
    }
    
    tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        
        // If on infected, print to entire team
        if (view_as<L4D2Team>(GetClientTeam(client)) == L4D2Team_Infected || (casterSystemAvailable && IsClientCaster(client)))
        {
            if (client == tankClientId) CPrintToChat(client, "{red}<{default}Tank Selection{red}> {green}You {default}will become the {red}Tank{default}!");
            else CPrintToChat(client, "{red}<{default}Tank Selection{red}> {olive}%s {default}will become the {red}Tank!", tankClientName);
        }
    }
    
    return Plugin_Handled;
}

/*
 * Allow players to vote on who should become tank
 */
public Action VoteTank_Cmd(int client, int args)
{
    if (!IS_VALID_INFECTED(client))
    {
        CPrintToChat(client, "{red}[Tank Vote] {default}Only infected can choose who will be the tank");
        return Plugin_Handled;
    }

    // If not in ready up, unable to vote
    if (!IsInReady())
    {
        CPrintToChat(client, "{red}[Tank Vote] {default}You are only able to vote during ready-up");
        return Plugin_Handled;
    }

    if (NumberOfPlayersInTeams() != 8)
    {
        CPrintToChat(client, "{red}[Tank Vote] {default}8 players are required to choose a tank");
        return Plugin_Handled;
    }

    if (hasVoted(client))
    {
        CPrintToChat(client, "{red}[Tank Vote] {default}You have already voted this round, move to spectator to reset votes");
        return Plugin_Handled;
    }
        
     // Who are we targetting?
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // If no argument passed through, show the menu
    if (arg1[0] == EOS)
    {
        displayVoteMenu(client);
        return Plugin_Handled;
    }

    // Try and find a matching player
    int target = FindTarget(0, arg1);
    if (target == -1)
    {
        CPrintToChat(client, "{red}[Tank Control] {default}The selected player was not found");
        return Plugin_Handled;
    }
    
    // Try to register the vote
    registerClientVote(client, target);

    return Plugin_Handled;
}

/**
 * Handler for the vote menu.
 *
 * @param Handle:menu
 *  The menu instantiating the handler.
 * @param MenuAction:action
 *  The menu action (i.e. Select/Cancel etc.)
 * @param param1
 *  The client id for user who made a selection.
 * @param param2
 *  The value for the menu choice (i.e. our case steam id)
 */
 
public int VoteMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            // Retrieve the target client id
            char targetSteamId[64];
            GetMenuItem(menu, param2, targetSteamId, sizeof(targetSteamId));

            int target = getInfectedPlayerBySteamId(targetSteamId);

            // Register the client vote
            registerClientVote(param1, target);
        }
 
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
     }
 
    return 0;
}

/**
 * Tells you whether a target steam id is in the tank pool
 * 
 * @param Handle:sourceHandle
 *     The pool of potential steam ids to become tank.
 * @param String:searchString
 *     The steam ids of player you are looking for.
 * 
 * @return
 *     TRUE is player is in pool, FALSE if not
 */
public bool inHandle(Handle sourceHandle, const char[] searchString)
{
    char arrayString[64];
    
    for (int i = 0; i < GetArraySize(sourceHandle); i++)
    {
        GetArrayString(sourceHandle, i, arrayString, sizeof(arrayString));
        if (strcmp(arrayString, searchString) == 0)
            return true;
    }
    
    return false;
}

public int NumberOfPlayersInTeams()
{
	int count = 0;
		
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || !SurvivorOrInfected(client))
			continue;

		count++;
	}

	return count;
}

public bool SurvivorOrInfected(int client)
{
	int clientTeam = GetClientTeam(client);
	
	return clientTeam == 2 || clientTeam == 3;
}

/**
 * Shuffle the tank (randomly give to another player in
 * the pool.
 */
 
public Action TankShuffle_Cmd(int client, int args)
{
    chooseTank(0);
    outputTankToAll(0);
    
    return Plugin_Handled;
}

/**
 * Give the tank to a specific player.
 */
 
public Action GiveTank_Cmd(int client, int args)
{    
    // Who are we targetting?
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Try and find a matching player
    int target = FindTarget(client, arg1);
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    // Get the players name
    char name[MAX_NAME_LENGTH];
    GetClientName(target, name, sizeof(name));
    
    // Set the tank
    if (IsClientInGame(target) && ! IsFakeClient(target))
    {
        // Checking if on our desired team
        if (view_as<L4D2Team>(GetClientTeam(target)) != L4D2Team_Infected)
        {
            CPrintToChatAll("{olive}[SM] {default}%s not on infected. Unable to give tank", name);
            return Plugin_Handled;
        }
        
        char steamId[64];
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

        strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
        outputTankToAll(0);
    }
    
    return Plugin_Handled;
}

/**
 * Selects a player on the infected team from random who hasn't been
 * tank and gives it to them.
 */
 
public void chooseTank(any data)
{
    if(chooseTankBasedOnVotes())
        return;

    // Create our pool of players to choose from
    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    addTeamSteamIdsToArray(infectedPool, L4D2Team_Infected);
    
    // If there is nobody on the infected team, return (otherwise we'd be stuck trying to select forever)
    if (GetArraySize(infectedPool) == 0)
    {
        delete infectedPool;
        return;
    }

    // Remove players who've already had tank from the pool.
    removeTanksFromPool(infectedPool, h_whosHadTank);
    
    // If the infected pool is empty, remove infected players from pool
    if (GetArraySize(infectedPool) == 0) // (when nobody on infected ,error)
    {
        ArrayList infectedTeam = new ArrayList(ByteCountToCells(64));
        addTeamSteamIdsToArray(infectedTeam, L4D2Team_Infected);
        if (GetArraySize(infectedTeam) > 1)
        {
            removeTanksFromPool(h_whosHadTank, infectedTeam);
            chooseTank(0);
        }
        else
        {
            queuedTankSteamId = "";
        }
        
        delete infectedTeam;
        delete infectedPool;
        return;
    }
    
    // Select a random person to become tank
    int rndIndex = GetRandomInt(0, GetArraySize(infectedPool) - 1);
    GetArrayString(infectedPool, rndIndex, queuedTankSteamId, sizeof(queuedTankSteamId));
    delete infectedPool;
}

/**
 * Set the tank.
 *
 * Iterates through the handles to look for the player who has received the
 * most votes, and instructs l4d_tank_control to mark them as tank.
 */
 
public bool chooseTankBasedOnVotes() 
{
    // If nobody has voted on someone to become tank, nothing to do
    if (GetArraySize(h_tankVoteSteamIds) == 0)
    {
        clearHandles();
        return false;
    }
    
    char steamId[64];
    int mostVotes = 0;
    int mostVotesIndex = -1;
    int votes;
    
    // Iterate through tank votes and retrieve most voted player
    for (int i = 0; i < GetArraySize(h_tankVoteSteamIds); i++)
    {
        GetArrayString(h_tankVoteSteamIds, i, steamId, sizeof(steamId));
        votes = GetArrayCell(h_tankVotes, i);
        
        // If we have a new leader
        if (votes > mostVotes)
        {
            mostVotes = votes;
            mostVotesIndex = i;
        }
    }
    
    GetArrayString(h_tankVoteSteamIds, mostVotesIndex, steamId, sizeof(steamId));
    strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
    clearHandles();

    return true;
}

/**
 * Initialise the handles (also used to reset handles)
 */
 public void clearHandles()
{
    ClearArray(h_tankVotes);
    ClearArray(h_whosVoted);
    ClearArray(h_tankVoteSteamIds);
}

/**
 * Code which actually display the vote menu.
 *
 * @param client
 *  The client who the vote menu is being rendered for.
 */

 public void displayVoteMenu(int client)
 {
    // Variable declaration to hold our menu/client information
    int clientId;
    char steamId[64];
    char targetName[64];  

    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    addTeamSteamIdsToArray(infectedPool, L4D2Team_Infected);
    
    // If there is nobody on the infected team, return (otherwise we'd be stuck trying to select forever)
    if (GetArraySize(infectedPool) == 0)
    {
        delete infectedPool;
        return;
    }

    // Remove players who've already had tank from the pool.
    removeTanksFromPool(infectedPool, h_whosHadTank);

    Handle menu = CreateMenu(VoteMenuHandler, MENU_ACTIONS_DEFAULT);
    
    SetMenuTitle(menu, "Who should be the tank?");
   
    for (int i = 0; i < GetArraySize(infectedPool); i++)
    {
        GetArrayString(infectedPool, i, steamId, sizeof(steamId));
        clientId = getInfectedPlayerBySteamId(steamId);
        GetClientName(clientId, targetName, sizeof(targetName));
        
        AddMenuItem(menu, steamId, targetName);
    }

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 30);
}


/**
 * Registers a client vote.
 *
 * @param client
 *  The client casting the vote.
 * @param target
 *  The client id of the target player (player voted to become tank)
 */
 
public void registerClientVote(int client, int target)
{
    // Retrieve players in the infected pool
    char steamId[64];

    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    addTeamSteamIdsToArray(infectedPool, L4D2Team_Infected);
    
    // If there is nobody on the infected team, return (otherwise we'd be stuck trying to select forever)
    if (GetArraySize(infectedPool) == 0)
    {
        delete infectedPool;
        return;
    }

    // Remove players who've already had tank from the pool.
    removeTanksFromPool(infectedPool, h_whosHadTank);
    
    // Get the targetted player's name
    char targetName[64];
    GetClientName(target, targetName, sizeof(targetName));
    
    // Get the client name
    char clientName[64];
    GetClientName(client, clientName, sizeof(clientName));
    
    // Set the tank
    if (IS_VALID_INFECTED(target))
    {
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));
        if (inHandle(infectedPool, steamId))
        {
            if (!hasVoted(client))
            {
                registerTankVote(client, steamId);
                PrintToInfected("{red}[Tank Vote] {default}{olive}%s {default}has voted for {olive}%s", clientName, targetName);
            }
            else
                CPrintToChat(client, "{red}[Tank Vote] {default}You have already voted this round");
        }
        else
            CPrintToChat(client, "{red}[Tank Vote] {olive}%s {default}is not in the tank pool", targetName);
    }
    else
        CPrintToChat(client, "{red}[Tank Control] {default}{olive}%s {default}is not available to become tank", targetName);
    
    CloseHandle(infectedPool);
}

/**
 * Registers a tank vote
 *
 * @param client
 *     The client registering the vote.
 * @param String:targetSteamId[]
 *     The player the vote is being casted for to become tank.
 */
 
public void registerTankVote(int client, const char[] targetSteamId)
{    
    // Retrieve the client of the target steam id
    // If the client has already voted, do nothing (can not vote twice)
    if (hasVoted(client))
        return;

    // Retrieve the steam id of the client
    char steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    
    // If a player has already received a vote, update it
    if (inHandle(h_tankVoteSteamIds, targetSteamId))
    {
        int targetClientId = getInfectedPlayerBySteamId(targetSteamId);
        int index = getVotePlayerIndex(targetClientId);
        Handle currentVotes = GetArrayCell(h_tankVotes, index);

        SetArrayCell(h_tankVotes, index, ++currentVotes);
    }
     // If its the initial vote for a player
    else 
    {
        PushArrayString(h_tankVoteSteamIds, targetSteamId);
        PushArrayCell(h_tankVotes, 1);
    }
    
    // Mark the client as having voted
    PushArrayString(h_whosVoted, steamId);
}

/**
 * Whether or not a player has already voted for the round.
 
 * @param client
 *    The client whos being checked.
 *
 * @return
 *    TRUE if the player has voted, FALSE if not
 */
public bool hasVoted(int client)
{
    int index = getVotePlayerIndex(client);

    return index >= 0;
}

/**
 * The index in the handle of the player whos trying to be voted on
 
 * @param client
 *    The client whos being checked.
 *
 * @return
 *    The index (-1 if not found)
 */
 
public int getVotePlayerIndex(int client)
{
    // Retrieve the steam id of the client
    char steamId[64];
    char targetSteamId[64];
    
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

    // Has the client voted
    for (int i = 0; i < GetArraySize(h_tankVoteSteamIds); i++)
    {
        GetArrayString(h_tankVoteSteamIds, i, targetSteamId, sizeof(targetSteamId));
        if (strcmp(steamId, targetSteamId) == 0)
            return i;
    }
    
    return -1;
}

/**
 * Make sure we give the tank to our queued player.
 */
 
public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{    
    // Reset the tank's frustration if need be
    if (! IsFakeClient(tank_index)) 
    {
        PrintHintText(tank_index, "Rage Meter Refilled");
        for (int i = 1; i <= MaxClients; i++) 
        {
            if (! IsClientInGame(i) || GetClientTeam(i) != 3)
                continue;

            if (tank_index == i) CPrintToChat(i, "{red}<{default}Tank Rage{red}> {olive}Rage Meter {red}Refilled");
            else CPrintToChat(i, "{red}<{default}Tank Rage{red}> {default}({green}%N{default}'s) {olive}Rage Meter {red}Refilled", tank_index);
        }
        
        SetTankFrustration(tank_index, 100);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
        
        return Plugin_Handled;
    }
    
    // If we don't have a queued tank, choose one
    if (! strcmp(queuedTankSteamId, ""))
        chooseTank(0);
    
    // Mark the player as having had tank
    if (strcmp(queuedTankSteamId, "") != 0)
    {
        setTankTickets(queuedTankSteamId, 20000);
        PushArrayString(h_whosHadTank, queuedTankSteamId);
    }
    
    return Plugin_Continue;
}

/**
 * Sets the amount of tickets for a particular player, essentially giving them tank.
 */
 
public void setTankTickets(const char[] steamId, int tickets)
{
    int tankClientId = getInfectedPlayerBySteamId(steamId);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && ! IsFakeClient(i) && GetClientTeam(i) == 3)
        {
            L4D2Direct_SetTankTickets(i, (i == tankClientId) ? tickets : 0);
        }
    }
}

/**
 * Output who will become tank
 */
 
public void outputTankToAll(any data)
{
    char tankClientName[MAX_NAME_LENGTH];
    int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        if (GetConVarBool(hTankPrint))
        {
            CPrintToChatAll("{red}<{default}Tank Selection{red}> {olive}%s {default}will become the {red}Tank!", tankClientName);
        }
        else
        {
            for (int i = 1; i <= MaxClients; i++) 
            {
                if (!IS_VALID_INFECTED(i) && !IS_VALID_CASTER(i))
                continue;

                if (tankClientId == i) CPrintToChat(i, "{red}<{default}Tank Selection{red}> {green}You {default}will become the {red}Tank{default}!");
                else CPrintToChat(i, "{red}<{default}Tank Selection{red}> {olive}%s {default}will become the {red}Tank!", tankClientName);
            }
        }
    }
}

stock void PrintToInfected(const char[] Message, any ... )
{
    char sPrint[256];
    VFormat(sPrint, sizeof(sPrint), Message, 2);

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IS_VALID_INFECTED(i) && !IS_VALID_CASTER(i)) 
        { 
            continue; 
        }

        CPrintToChat(i, "{default}%s", sPrint);
    }
}
/**
 * Adds steam ids for a particular team to an array.
 * 
 * @ param Handle:steamIds
 *     The array steam ids will be added to.
 * @param L4D2Team:team
 *     The team to get steam ids for.
 */
 
public void addTeamSteamIdsToArray(ArrayList steamIds, L4D2Team team)
{
    char steamId[64];

    for (int i = 1; i <= MaxClients; i++)
    {
        // Basic check
        if (IsClientInGame(i) && ! IsFakeClient(i))
        {
            // Checking if on our desired team
            if (view_as<L4D2Team>(GetClientTeam(i)) != team)
                continue;
        
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            PushArrayString(steamIds, steamId);
        }
    }
}

/**
 * Removes steam ids from the tank pool if they've already had tank.
 * 
 * @param Handle:steamIdTankPool
 *     The pool of potential steam ids to become tank.
 * @ param Handle:tanks
 *     The steam ids of players who've already had tank.
 * 
 * @return
 *     The pool of steam ids who haven't had tank.
 */
 
public void removeTanksFromPool(ArrayList steamIdTankPool, ArrayList tanks)
{
    int index;
    char steamId[64];
    
    int ArraySize = GetArraySize(tanks);
    for (int i = 0; i < ArraySize; i++)
    {
        GetArrayString(tanks, i, steamId, sizeof(steamId));
        index = FindStringInArray(steamIdTankPool, steamId);
        
        if (index != -1)
        {
            RemoveFromArray(steamIdTankPool, index);
        }
    }
}

/**
 * Retrieves a player's client index by their steam id.
 * 
 * @param const String:steamId[]
 *     The steam id to look for.
 * 
 * @return
 *     The player's client index.
 */
 
public int getInfectedPlayerBySteamId(const char[] steamId) 
{
    char tmpSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 3)
            continue;
        
        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));     
        
        if (strcmp(steamId, tmpSteamId) == 0)
            return i;
    }
    
    return -1;
}

void SetTankFrustration(int iTankClient, int iFrustration) {
    if (iFrustration < 0 || iFrustration > 100) {
        return;
    }
    
    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}