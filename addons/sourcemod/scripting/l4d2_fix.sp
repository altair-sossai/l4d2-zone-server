#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <builtinvotes>
#include <colors>

#undef REQUIRE_PLUGIN
#include <readyup>
#include <pause>
#define REQUIRE_PLUGIN

#define TAG "{green}[Fix]{default} "
#define ADMIN_OVERRIDE "sm_fix_admin"

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ZOMBIECLASS_TANK 8
#define SLOT_PILLS 4

#define CATEGORY_HEALTH "h"
#define CATEGORY_PILLS "p"
#define CATEGORY_REVIVE "r"
#define CATEGORY_TANK "t"

#define CONFIRM_VOTE "vote"
#define CONFIRM_APPLY "apply"

enum FixAction
{
    FixAction_None,
    FixAction_Permanent,
    FixAction_Perm,
    FixAction_Temp,
    FixAction_Pills,
    FixAction_Revive,
    FixAction_Tank
}

int g_HealthAmounts[] = { 100, 90, 80, 70, 60, 50 };

ConVar g_cvEnabled,
       g_cvVoteDuration,
       g_cvCooldown,
       g_cvRoundLimit;

bool g_bReadyUpAvailable = false,
     g_bPauseAvailable = false,
     g_bRoundLive = false;

Handle g_hVote = null;

bool g_bVoteResolved = false,
     g_bCancellingVote = false;

FixAction g_VoteAction = FixAction_None;

int g_iVoteTarget = 0,
    g_iVoteAmount = 0,
    g_iVoteTeam = 0,
    g_iVoteRoster[MAXPLAYERS + 1];

char g_sVoteRequester[MAX_NAME_LENGTH],
     g_sVoteTargetName[MAX_NAME_LENGTH];

float g_flNextRequest[MAXPLAYERS + 1];

int g_iApproved[TEAM_INFECTED + 1];

FixAction g_MenuAction[MAXPLAYERS + 1];

int g_iMenuTarget[MAXPLAYERS + 1],
    g_iMenuAmount[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "L4D2 Fix",
    author      = "Altair Sossai",
    description = "Lets players fix a survivor's health, give pills, revive a survivor or restore the Tank's health through a vote of the other team; admins apply it right away",
    version     = "1.0.0",
    url         = "https://github.com/altair-sossai/l4d2-zone-server"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_fix.phrases");

    g_cvEnabled = CreateConVar("l4d2_fix_enabled", "1", "1 = players can ask for fixes through a vote, 0 = only admins can use !fix", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvVoteDuration = CreateConVar("l4d2_fix_vote_duration", "15", "Duration of the !fix vote, in seconds", FCVAR_NONE, true, 5.0, true, 60.0);
    g_cvCooldown = CreateConVar("l4d2_fix_cooldown", "60", "Seconds a player waits after starting a !fix vote before starting another", FCVAR_NONE, true, 0.0);
    g_cvRoundLimit = CreateConVar("l4d2_fix_round_limit", "3", "Approved !fix votes each team can benefit from in a round (0 = no limit)", FCVAR_NONE, true, 0.0);

    RegConsoleCmd("sm_fix", FixCmd, "Opens the !fix menu to fix a survivor's health, give pills, revive a survivor or restore the Tank's health");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

    g_bRoundLive = L4D_HasMapStarted();
}

public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
    g_bPauseAvailable = LibraryExists("pause");
}

public void OnLibraryAdded(const char[] name)
{
    SetLibraryAvailable(name, true);
}

public void OnLibraryRemoved(const char[] name)
{
    SetLibraryAvailable(name, false);
}

void SetLibraryAvailable(const char[] name, bool available)
{
    if (StrEqual(name, "readyup"))
        g_bReadyUpAvailable = available;

    if (StrEqual(name, "pause"))
        g_bPauseAvailable = available;
}

public void OnMapStart()
{
    g_bRoundLive = false;

    ResetRoundCounters();

    for (int i = 1; i <= MaxClients; i++)
        g_flNextRequest[i] = 0.0;
}

public void OnMapEnd()
{
    g_bRoundLive = false;

    CancelFixVote();
}

public void OnClientConnected(int client)
{
    g_flNextRequest[client] = 0.0;
    g_MenuAction[client] = FixAction_None;
    g_iMenuTarget[client] = 0;
    g_iMenuAmount[client] = 0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundLive = true;

    ResetRoundCounters();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundLive = false;

    CancelFixVote();
}

void CancelFixVote()
{
    if (g_hVote == null || g_bVoteResolved)
        return;

    g_bCancellingVote = true;
    CancelBuiltinVote();
    g_bCancellingVote = false;
}

void ResetRoundCounters()
{
    for (int i = 0; i < sizeof(g_iApproved); i++)
        g_iApproved[i] = 0;
}

public Action FixCmd(int client, int args)
{
    if (client <= 0 || !IsClientInGame(client))
    {
        ReplyToCommand(client, "[Fix] %t", "InGameOnly");
        return Plugin_Handled;
    }

    if (!IsFixAdmin(client) && !CanRequest(client))
        return Plugin_Handled;

    ShowMainMenu(client);

    return Plugin_Handled;
}

bool IsFixAdmin(int client)
{
    return CheckCommandAccess(client, ADMIN_OVERRIDE, ADMFLAG_KICK, true);
}

bool IsReadyUp()
{
    return g_bReadyUpAvailable && IsInReady();
}

bool IsPaused()
{
    return g_bPauseAvailable && IsInPause();
}

bool IsRoundLive()
{
    return g_bRoundLive && !IsReadyUp() && !IsPaused();
}

bool CanRequest(int client)
{
    if (!g_cvEnabled.BoolValue)
    {
        CPrintToChat(client, "%s%t", TAG, "AdminsOnly");
        return false;
    }

    int team = GetClientTeam(client);
    if (team != TEAM_SURVIVOR && team != TEAM_INFECTED)
    {
        CPrintToChat(client, "%s%t", TAG, "TeamsOnly");
        return false;
    }

    if (!g_bRoundLive || IsReadyUp())
    {
        CPrintToChat(client, "%s%t", TAG, "NotLive");
        return false;
    }

    if (IsPaused())
    {
        CPrintToChat(client, "%s%t", TAG, "Paused");
        return false;
    }

    if (g_hVote != null || IsBuiltinVoteInProgress())
    {
        CPrintToChat(client, "%s%t", TAG, "VoteBusy");
        return false;
    }

    int delay = CheckBuiltinVoteDelay();
    if (delay > 0)
    {
        CPrintToChat(client, "%s%t", TAG, "Wait", delay);
        return false;
    }

    float remaining = g_flNextRequest[client] - GetGameTime();
    if (remaining > 0.0)
    {
        CPrintToChat(client, "%s%t", TAG, "Wait", RoundToCeil(remaining));
        return false;
    }

    return true;
}

void ShowMainMenu(int client)
{
    Menu menu = new Menu(MainMenuHandler);
    menu.SetTitle("%T", "MenuTitle", client);

    AddCategoryItem(menu, client, CATEGORY_HEALTH, "MenuHealth");
    AddCategoryItem(menu, client, CATEGORY_PILLS, "MenuPills");
    AddCategoryItem(menu, client, CATEGORY_REVIVE, "MenuRevive");

    if (HasAliveTank())
        AddCategoryItem(menu, client, CATEGORY_TANK, "MenuTank");

    menu.Display(client, MENU_TIME_FOREVER);
}

void AddCategoryItem(Menu menu, int client, const char[] category, const char[] phrase)
{
    char display[128];

    if (HasCategoryTarget(category))
    {
        FormatEx(display, sizeof(display), "%T", phrase, client);
        menu.AddItem(category, display);
        return;
    }

    char label[96];
    FormatEx(label, sizeof(label), "%T", phrase, client);
    FormatEx(display, sizeof(display), "%T", "NobodyNow", client, label);
    menu.AddItem(category, display, ITEMDRAW_DISABLED);
}

int MainMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action != MenuAction_Select)
        return 0;

    char category[4];
    menu.GetItem(param2, category, sizeof(category));

    if (!HasCategoryTarget(category))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowMainMenu(client);
        return 0;
    }

    ShowTargetMenu(client, category);

    return 0;
}

bool HasCategoryTarget(const char[] category)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsCategoryTarget(category, i))
            return true;
    }

    return false;
}

bool IsCategoryTarget(const char[] category, int target)
{
    if (StrEqual(category, CATEGORY_HEALTH))
        return IsHealthTarget(target);

    if (StrEqual(category, CATEGORY_PILLS))
        return IsPillsTarget(target);

    if (StrEqual(category, CATEGORY_REVIVE))
        return IsReviveTarget(target);

    if (StrEqual(category, CATEGORY_TANK))
        return IsTankTarget(target);

    return false;
}

void ShowTargetMenu(int client, const char[] category)
{
    if (!HasCategoryTarget(category))
    {
        ShowMainMenu(client);
        return;
    }

    Menu menu = new Menu(TargetMenuHandler);
    menu.SetTitle("%T", StrEqual(category, CATEGORY_TANK) ? "PickTankTitle" : "PickSurvivorTitle", client);
    menu.ExitBackButton = true;

    char info[16];
    char display[128];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsCategoryTarget(category, i))
            continue;

        FormatEx(info, sizeof(info), "%s:%d", category, GetClientUserId(i));
        FormatTargetLine(client, category, i, display, sizeof(display));
        menu.AddItem(info, display);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

void FormatTargetLine(int client, const char[] category, int target, char[] buffer, int maxlen)
{
    char name[MAX_NAME_LENGTH];
    GetPlainName(target, name, sizeof(name));

    if (StrEqual(category, CATEGORY_TANK))
    {
        FormatEx(buffer, maxlen, "%T", "TankLine", client, name, GetClientHealth(target), GetMaxHealth(target));
        return;
    }

    if (IsDown(target))
    {
        FormatEx(buffer, maxlen, "%T", L4D_IsPlayerHangingFromLedge(target) ? "HangingLine" : "DownedLine", client, name);
        return;
    }

    if (StrEqual(category, CATEGORY_HEALTH))
    {
        FormatEx(buffer, maxlen, "%T", "HealthLine", client, name, GetClientHealth(target), GetTempHealth(target));
        return;
    }

    strcopy(buffer, maxlen, name);
}

int TargetMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
            ShowMainMenu(client);

        return 0;
    }

    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(param2, info, sizeof(info));

    char parts[2][12];
    if (ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 2)
        return 0;

    int target = GetClientOfUserId(StringToInt(parts[1]));
    if (!IsCategoryTarget(parts[0], target))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowTargetMenu(client, parts[0]);
        return 0;
    }

    if (StrEqual(parts[0], CATEGORY_HEALTH))
    {
        ShowHealthMenu(client, target);
        return 0;
    }

    if (StrEqual(parts[0], CATEGORY_PILLS))
    {
        ShowConfirmMenu(client, FixAction_Pills, target, 0);
        return 0;
    }

    if (StrEqual(parts[0], CATEGORY_REVIVE))
    {
        ShowConfirmMenu(client, FixAction_Revive, target, 0);
        return 0;
    }

    ShowConfirmMenu(client, FixAction_Tank, target, 0);

    return 0;
}

void ShowHealthMenu(int client, int target)
{
    char name[MAX_NAME_LENGTH];
    GetPlainName(target, name, sizeof(name));

    Menu menu = new Menu(HealthMenuHandler);
    menu.SetTitle("%T", "HealthTitle", client, name, GetClientHealth(target), GetTempHealth(target));
    menu.ExitBackButton = true;

    char info[16];
    char display[128];
    int userid = GetClientUserId(target);

    FormatEx(info, sizeof(info), "%d:%d", view_as<int>(FixAction_Permanent), userid);
    FormatEx(display, sizeof(display), "%T", "OptionPermanent", client, PermanentTotal(target));
    menu.AddItem(info, display, CanApply(FixAction_Permanent, target, 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    FormatEx(info, sizeof(info), "%d:%d", view_as<int>(FixAction_Perm), userid);
    FormatEx(display, sizeof(display), "%T", "OptionPermMenu", client);
    menu.AddItem(info, display, HasAmountOption(client, FixAction_Perm, target) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    FormatEx(info, sizeof(info), "%d:%d", view_as<int>(FixAction_Temp), userid);
    FormatEx(display, sizeof(display), "%T", "OptionTempMenu", client);
    menu.AddItem(info, display, HasAmountOption(client, FixAction_Temp, target) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    menu.Display(client, MENU_TIME_FOREVER);
}

int HealthMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
            ShowTargetMenu(client, CATEGORY_HEALTH);

        return 0;
    }

    if (action != MenuAction_Select)
        return 0;

    char info[16];
    menu.GetItem(param2, info, sizeof(info));

    char parts[2][12];
    if (ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 2)
        return 0;

    FixAction option = view_as<FixAction>(StringToInt(parts[0]));
    int target = GetClientOfUserId(StringToInt(parts[1]));

    if (!IsHealthTarget(target))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowTargetMenu(client, CATEGORY_HEALTH);
        return 0;
    }

    if (option == FixAction_Perm || option == FixAction_Temp)
    {
        ShowAmountMenu(client, option, target);
        return 0;
    }

    if (!CanApplyFor(client, option, target, 0))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowHealthMenu(client, target);
        return 0;
    }

    ShowConfirmMenu(client, option, target, 0);

    return 0;
}

bool HasAmountOption(int client, FixAction fix, int target)
{
    for (int i = 0; i < sizeof(g_HealthAmounts); i++)
    {
        if (CanApplyFor(client, fix, target, g_HealthAmounts[i]))
            return true;
    }

    return false;
}

void ShowAmountMenu(int client, FixAction fix, int target)
{
    g_MenuAction[client] = fix;
    g_iMenuTarget[client] = GetClientUserId(target);
    g_iMenuAmount[client] = 0;

    char name[MAX_NAME_LENGTH];
    GetPlainName(target, name, sizeof(name));

    Menu menu = new Menu(AmountMenuHandler);
    menu.SetTitle("%T", fix == FixAction_Temp ? "AmountTitleTemp" : "AmountTitlePerm", client, name, GetClientHealth(target), GetTempHealth(target));
    menu.ExitBackButton = true;

    char info[24];
    char display[64];
    int userid = GetClientUserId(target);
    bool admin = IsFixAdmin(client);

    for (int i = 0; i < sizeof(g_HealthAmounts); i++)
    {
        int amount = g_HealthAmounts[i];

        if (!admin && LowersHealth(fix, target, amount))
            continue;

        FormatEx(info, sizeof(info), "%d:%d:%d", view_as<int>(fix), userid, amount);
        FormatEx(display, sizeof(display), "%T", fix == FixAction_Temp ? "OptionTemp" : "OptionPerm", client, amount);
        menu.AddItem(info, display, CanApply(fix, target, amount) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

int AmountMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
            ShowHealthOrTargetMenu(client, GetClientOfUserId(g_iMenuTarget[client]));

        return 0;
    }

    if (action != MenuAction_Select)
        return 0;

    char info[24];
    menu.GetItem(param2, info, sizeof(info));

    char parts[3][12];
    if (ExplodeString(info, ":", parts, sizeof(parts), sizeof(parts[])) != 3)
        return 0;

    FixAction fix = view_as<FixAction>(StringToInt(parts[0]));
    int target = GetClientOfUserId(StringToInt(parts[1]));
    int amount = StringToInt(parts[2]);

    if (!CanApplyFor(client, fix, target, amount))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowAmountOrTargetMenu(client, fix, target);
        return 0;
    }

    ShowConfirmMenu(client, fix, target, amount);

    return 0;
}

void ShowConfirmMenu(int client, FixAction fix, int target, int amount)
{
    g_MenuAction[client] = fix;
    g_iMenuTarget[client] = GetClientUserId(target);
    g_iMenuAmount[client] = amount;

    char name[MAX_NAME_LENGTH];
    GetPlainName(target, name, sizeof(name));

    char description[192];
    Describe(fix, name, amount, client, description, sizeof(description));

    Menu menu = new Menu(ConfirmMenuHandler);
    menu.SetTitle("%T", "ConfirmTitle", client, description);
    menu.ExitBackButton = true;

    AddConfirmItem(menu, client, fix);

    menu.Display(client, MENU_TIME_FOREVER);
}

void AddConfirmItem(Menu menu, int client, FixAction fix)
{
    char display[128];

    if (IsFixAdmin(client))
    {
        FormatEx(display, sizeof(display), "%T", "ConfirmApply", client);
        menu.AddItem(CONFIRM_APPLY, display);
        return;
    }

    char teamName[32];
    FormatTeamName(VotingTeam(fix), client, teamName, sizeof(teamName));
    FormatEx(display, sizeof(display), "%T", "ConfirmVote", client, teamName);
    menu.AddItem(CONFIRM_VOTE, display);
}

void FormatTeamName(int team, int lang, char[] buffer, int maxlen)
{
    FormatEx(buffer, maxlen, "%T", team == TEAM_SURVIVOR ? "TeamSurvivors" : "TeamInfected", lang);
}

int ConfirmMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        return 0;
    }

    if (action == MenuAction_Cancel)
    {
        if (param2 == MenuCancel_ExitBack)
            ShowPreviousMenu(client);

        return 0;
    }

    if (action != MenuAction_Select)
        return 0;

    FixAction fix = g_MenuAction[client];
    int target = GetClientOfUserId(g_iMenuTarget[client]);
    int amount = g_iMenuAmount[client];

    if (!CanApplyFor(client, fix, target, amount))
    {
        CPrintToChat(client, "%s%t", TAG, "TargetGone");
        ShowPreviousMenu(client);
        return 0;
    }

    char choice[8];
    menu.GetItem(param2, choice, sizeof(choice));

    if (StrEqual(choice, CONFIRM_APPLY))
    {
        ApplyAsAdmin(client, fix, target, amount);
        return 0;
    }

    StartFixVote(client, fix, target, amount);

    return 0;
}

void ShowPreviousMenu(int client)
{
    FixAction fix = g_MenuAction[client];
    int target = GetClientOfUserId(g_iMenuTarget[client]);

    if (fix == FixAction_Pills)
    {
        ShowTargetMenu(client, CATEGORY_PILLS);
        return;
    }

    if (fix == FixAction_Revive)
    {
        ShowTargetMenu(client, CATEGORY_REVIVE);
        return;
    }

    if (fix == FixAction_Tank)
    {
        ShowTargetMenu(client, CATEGORY_TANK);
        return;
    }

    if (fix == FixAction_Perm || fix == FixAction_Temp)
    {
        ShowAmountOrTargetMenu(client, fix, target);
        return;
    }

    ShowHealthOrTargetMenu(client, target);
}

void ShowAmountOrTargetMenu(int client, FixAction fix, int target)
{
    if (IsHealthTarget(target) && HasAmountOption(client, fix, target))
    {
        ShowAmountMenu(client, fix, target);
        return;
    }

    ShowHealthOrTargetMenu(client, target);
}

void ShowHealthOrTargetMenu(int client, int target)
{
    if (IsHealthTarget(target))
    {
        ShowHealthMenu(client, target);
        return;
    }

    ShowTargetMenu(client, CATEGORY_HEALTH);
}

void ApplyAsAdmin(int client, FixAction fix, int target, int amount)
{
    if (!IsFixAdmin(client))
        return;

    char adminName[MAX_NAME_LENGTH];
    GetPlainName(client, adminName, sizeof(adminName));

    char targetName[MAX_NAME_LENGTH];
    GetPlainName(target, targetName, sizeof(targetName));

    ApplyFix(fix, target, amount);

    char description[192];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        Describe(fix, targetName, amount, i, description, sizeof(description));
        CPrintToChat(i, "%s%T", TAG, "AdminApplied", i, adminName, description);
    }

    Describe(fix, targetName, amount, LANG_SERVER, description, sizeof(description));
    LogAction(client, target, "\"%L\" applied !fix as admin: %s", client, description);
}

void StartFixVote(int client, FixAction fix, int target, int amount)
{
    if (!CanRequest(client))
        return;

    int voteTeam = VotingTeam(fix);
    int benefited = voteTeam == TEAM_SURVIVOR ? TEAM_INFECTED : TEAM_SURVIVOR;

    char teamName[32];

    int limit = g_cvRoundLimit.IntValue;
    if (limit > 0 && g_iApproved[benefited] >= limit)
    {
        FormatTeamName(benefited, client, teamName, sizeof(teamName));
        CPrintToChat(client, "%s%t", TAG, "RoundLimit", teamName, limit);
        return;
    }

    int[] players = new int[MaxClients];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_iVoteRoster[i] = 0;

        if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != voteTeam)
            continue;

        players[count++] = i;
        g_iVoteRoster[i] = GetClientUserId(i);
    }

    if (count == 0)
    {
        FormatTeamName(voteTeam, client, teamName, sizeof(teamName));
        CPrintToChat(client, "%s%t", TAG, "NoVoters", teamName);
        return;
    }

    g_hVote = CreateBuiltinVote(FixVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_End);
    if (g_hVote == null)
    {
        CPrintToChat(client, "%s%t", TAG, "VoteBusy");
        return;
    }

    g_bVoteResolved = false;
    g_VoteAction = fix;
    g_iVoteTarget = GetClientUserId(target);
    g_iVoteAmount = amount;
    g_iVoteTeam = voteTeam;
    GetPlainName(client, g_sVoteRequester, sizeof(g_sVoteRequester));
    GetPlainName(target, g_sVoteTargetName, sizeof(g_sVoteTargetName));

    char description[192];
    Describe(fix, g_sVoteTargetName, amount, LANG_SERVER, description, sizeof(description));

    char title[256];
    FormatEx(title, sizeof(title), "%T", "VoteTitle", LANG_SERVER, description);

    SetBuiltinVoteArgument(g_hVote, title);
    SetBuiltinVoteInitiator(g_hVote, client);
    SetBuiltinVoteTeam(g_hVote, voteTeam);
    SetBuiltinVoteResultCallback(g_hVote, FixVoteResultHandler);

    if (!DisplayBuiltinVote(g_hVote, players, count, g_cvVoteDuration.IntValue))
    {
        delete g_hVote;
        CPrintToChat(client, "%s%t", TAG, "VoteBusy");
        return;
    }

    g_flNextRequest[client] = GetGameTime() + g_cvCooldown.FloatValue;

    LogAction(client, target, "\"%L\" started a !fix vote: %s", client, description);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        Describe(fix, g_sVoteTargetName, amount, i, description, sizeof(description));
        FormatTeamName(voteTeam, i, teamName, sizeof(teamName));
        CPrintToChat(i, "%s%T", TAG, "VoteStarted", i, g_sVoteRequester, description, teamName);
    }

    if (g_iVoteRoster[client] != 0)
        RequestFrame(AutoVoteYes_Frame, GetClientUserId(client));
}

void AutoVoteYes_Frame(any userid)
{
    int client = GetClientOfUserId(userid);
    if (client <= 0 || g_hVote == null || g_bVoteResolved || g_iVoteRoster[client] != userid)
        return;

    FakeClientCommand(client, "Vote Yes");
}

void FixVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    if (action == BuiltinVoteAction_End)
    {
        if (vote == g_hVote)
            g_hVote = null;

        delete vote;
        return;
    }

    if (action != BuiltinVoteAction_Cancel || vote != g_hVote || g_bVoteResolved)
        return;

    g_bVoteResolved = true;

    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
    AnnounceVote(g_bCancellingVote ? "VoteCancelled" : "VoteFailed");
}

void FixVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    if (vote != g_hVote || g_bVoteResolved)
        return;

    g_bVoteResolved = true;

    int yes = 0;
    int no = 0;

    for (int i = 0; i < num_clients; i++)
    {
        int voter = client_info[i][BUILTINVOTEINFO_CLIENT_INDEX];
        if (voter <= 0 || voter > MaxClients || !IsClientInGame(voter))
            continue;

        if (g_iVoteRoster[voter] != GetClientUserId(voter) || GetClientTeam(voter) != g_iVoteTeam)
            continue;

        int item = client_info[i][BUILTINVOTEINFO_CLIENT_ITEM];

        if (item == BUILTINVOTES_VOTE_YES)
            yes++;

        if (item == BUILTINVOTES_VOTE_NO)
            no++;
    }

    if (yes <= no)
    {
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
        AnnounceVote("VoteFailed");
        return;
    }

    int target = GetClientOfUserId(g_iVoteTarget);
    if (!IsRoundLive() || !CanApply(g_VoteAction, target, g_iVoteAmount) || LowersHealth(g_VoteAction, target, g_iVoteAmount))
    {
        DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
        AnnounceVote("NoLongerValid");
        return;
    }

    ApplyFix(g_VoteAction, target, g_iVoteAmount);

    int benefited = g_iVoteTeam == TEAM_SURVIVOR ? TEAM_INFECTED : TEAM_SURVIVOR;
    g_iApproved[benefited]++;

    char passed[64];
    FormatEx(passed, sizeof(passed), "%T", "VotePassScreen", LANG_SERVER);
    DisplayBuiltinVotePass(vote, passed);

    AnnounceVote("VotePassed");

    char description[192];
    Describe(g_VoteAction, g_sVoteTargetName, g_iVoteAmount, LANG_SERVER, description, sizeof(description));
    LogAction(-1, target, "!fix vote passed (%d yes, %d no): %s", yes, no, description);
}

void AnnounceVote(const char[] phrase)
{
    char description[192];

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        Describe(g_VoteAction, g_sVoteTargetName, g_iVoteAmount, i, description, sizeof(description));
        CPrintToChat(i, "%s%T", TAG, phrase, i, description);
    }
}

void ApplyFix(FixAction fix, int target, int amount)
{
    switch (fix)
    {
        case FixAction_Permanent:
            SetSurvivorHealth(target, PermanentTotal(target), 0);
        case FixAction_Perm:
            SetSurvivorHealth(target, amount, 0);
        case FixAction_Temp:
            SetSurvivorHealth(target, 1, amount - 1);
        case FixAction_Pills:
            GivePlayerItem(target, "weapon_pain_pills");
        case FixAction_Revive:
            L4D_ReviveSurvivor(target);
        case FixAction_Tank:
            SetEntityHealth(target, GetMaxHealth(target));
    }
}

void SetSurvivorHealth(int target, int health, int temp)
{
    SetEntityHealth(target, health);
    L4D_SetTempHealth(target, float(temp));
}

bool CanApply(FixAction fix, int target, int amount)
{
    switch (fix)
    {
        case FixAction_Permanent:
            return IsHealthTarget(target) && GetTempHealth(target) > 0;
        case FixAction_Perm, FixAction_Temp:
            return IsHealthTarget(target) && IsValidAmount(amount) && !HasHealth(fix, target, amount);
        case FixAction_Pills:
            return IsPillsTarget(target);
        case FixAction_Revive:
            return IsReviveTarget(target);
        case FixAction_Tank:
            return IsTankTarget(target);
    }

    return false;
}

bool IsValidAmount(int amount)
{
    for (int i = 0; i < sizeof(g_HealthAmounts); i++)
    {
        if (g_HealthAmounts[i] == amount)
            return true;
    }

    return false;
}

bool CanApplyFor(int client, FixAction fix, int target, int amount)
{
    if (!CanApply(fix, target, amount))
        return false;

    return IsFixAdmin(client) || !LowersHealth(fix, target, amount);
}

bool LowersHealth(FixAction fix, int target, int amount)
{
    if (fix != FixAction_Perm && fix != FixAction_Temp)
        return false;

    int health = GetClientHealth(target);
    int total = health + GetTempHealth(target);

    if (fix == FixAction_Temp)
        return health > 1 || amount < total;

    return amount < total;
}

bool HasHealth(FixAction fix, int target, int amount)
{
    if (fix == FixAction_Temp)
        return GetClientHealth(target) == 1 && GetTempHealth(target) == amount - 1;

    return GetClientHealth(target) == amount && GetTempHealth(target) == 0;
}

int PermanentTotal(int target)
{
    int total = GetClientHealth(target) + GetTempHealth(target);
    int max = GetMaxHealth(target);

    return total > max ? max : total;
}

int VotingTeam(FixAction fix)
{
    return fix == FixAction_Tank ? TEAM_SURVIVOR : TEAM_INFECTED;
}

void Describe(FixAction fix, const char[] name, int amount, int lang, char[] buffer, int maxlen)
{
    switch (fix)
    {
        case FixAction_Permanent:
            FormatEx(buffer, maxlen, "%T", "DescPermanent", lang, name);
        case FixAction_Perm:
            FormatEx(buffer, maxlen, "%T", "DescPerm", lang, name, amount);
        case FixAction_Temp:
            FormatEx(buffer, maxlen, "%T", "DescTemp", lang, name, amount);
        case FixAction_Pills:
            FormatEx(buffer, maxlen, "%T", "DescPills", lang, name);
        case FixAction_Revive:
            FormatEx(buffer, maxlen, "%T", "DescRevive", lang, name);
        case FixAction_Tank:
            FormatEx(buffer, maxlen, "%T", "DescTank", lang, name);
        default:
            buffer[0] = '\0';
    }
}

bool IsAliveSurvivor(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;

    return GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client);
}

bool IsDown(int client)
{
    return L4D_IsPlayerIncapacitated(client) || L4D_IsPlayerHangingFromLedge(client);
}

bool IsHealthTarget(int client)
{
    return IsAliveSurvivor(client) && !IsDown(client);
}

bool IsPillsTarget(int client)
{
    return IsAliveSurvivor(client) && GetPlayerWeaponSlot(client, SLOT_PILLS) == -1;
}

bool IsReviveTarget(int client)
{
    if (!IsAliveSurvivor(client) || !IsDown(client) || L4D_IsPlayerPinned(client))
        return false;

    if (GetEntPropEnt(client, Prop_Send, "m_reviveOwner") != -1)
        return false;

    return !GetEntProp(client, Prop_Send, "m_isFallingFromLedge");
}

bool IsAliveTank(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;

    if (GetClientTeam(client) != TEAM_INFECTED || !IsPlayerAlive(client) || L4D_IsPlayerGhost(client))
        return false;

    return GetEntProp(client, Prop_Send, "m_zombieClass") == ZOMBIECLASS_TANK && !L4D_IsPlayerIncapacitated(client);
}

bool IsTankTarget(int client)
{
    return IsAliveTank(client) && GetClientHealth(client) < GetMaxHealth(client);
}

bool HasAliveTank()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsAliveTank(i))
            return true;
    }

    return false;
}

int GetTempHealth(int client)
{
    return RoundToFloor(L4D_GetTempHealth(client));
}

int GetMaxHealth(int client)
{
    return GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

void GetPlainName(int client, char[] buffer, int maxlen)
{
    GetClientName(client, buffer, maxlen);
    CRemoveTags(buffer, maxlen);
}
