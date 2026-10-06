#include <open.mp>

#define MATCH_MODE_DM                 (0)
#define MATCH_MODE_TDM                (1)
#define DEFAULT_MATCH_MODE            MATCH_MODE_TDM

#define TEAM_NONE                     (0)
#define TEAM_RED                      (1)
#define TEAM_BLUE                     (2)

#define MATCH_KILL_LIMIT              (30)
#define MATCH_LENGTH_SECONDS          (15 * 60)
#define ROUND_INTERMISSION_MS         (8000)

#define COLOR_WHITE                   (0xFFFFFFFF)
#define COLOR_RED                     (0xE74C3CFF)
#define COLOR_BLUE                    (0x3498DBFF)
#define COLOR_YELLOW                  (0xF1C40FFF)
#define COLOR_GREEN                   (0x2ECC71FF)

new gMatchMode = DEFAULT_MATCH_MODE;
new gTeamScore[TEAM_BLUE + 1];
new gPlayerTeam[MAX_PLAYERS];
new gPlayerKills[MAX_PLAYERS];
new gPlayerDeaths[MAX_PLAYERS];
new gMatchSecondsRemaining = MATCH_LENGTH_SECONDS;
new gMatchFinished;
new gMatchTimer;

forward MatchTimerTick();
forward RestartRound();

public OnGameModeInit()
{
    if (gMatchMode == MATCH_MODE_TDM)
    {
        SetGameModeText("Team Deathmatch");
        print("[DM/TDM] Team Deathmatch mode loaded.");
    }
    else
    {
        SetGameModeText("Deathmatch");
        print("[DM/TDM] Deathmatch mode loaded.");
    }

    AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    SetWorldTime(12);
    SetWeather(10);

    gTeamScore[TEAM_RED] = 0;
    gTeamScore[TEAM_BLUE] = 0;
    gMatchFinished = 0;
    gMatchSecondsRemaining = MATCH_LENGTH_SECONDS;
    gMatchTimer = SetTimer("MatchTimerTick", 1000, true);

    return 1;
}

public OnGameModeExit()
{
    if (gMatchTimer != 0)
    {
        KillTimer(gMatchTimer);
    }
    return 1;
}

public OnPlayerConnect(playerid)
{
    gPlayerTeam[playerid] = TEAM_NONE;
    gPlayerKills[playerid] = 0;
    gPlayerDeaths[playerid] = 0;

    AssignPlayerTeam(playerid);
    SendClientMessage(playerid, COLOR_WHITE, "Welcome to DM/TDM! Type /help for commands.");

    if (gMatchMode == MATCH_MODE_TDM)
    {
        if (gPlayerTeam[playerid] == TEAM_RED)
        {
            SendClientMessage(playerid, COLOR_RED, "You joined the RED team.");
        }
        else
        {
            SendClientMessage(playerid, COLOR_BLUE, "You joined the BLUE team.");
        }
    }
    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    gPlayerTeam[playerid] = TEAM_NONE;
    gPlayerKills[playerid] = 0;
    gPlayerDeaths[playerid] = 0;
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    SendClientMessage(playerid, COLOR_YELLOW, "Choose your class and press Spawn to join the match.");
    return 1;
}

public OnPlayerSpawn(playerid)
{
    if (gMatchFinished)
    {
        TogglePlayerControllable(playerid, false);
        return 1;
    }

    TogglePlayerControllable(playerid, true);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    ApplyPlayerSpawn(playerid);

    ResetPlayerWeapons(playerid);
    GivePlayerWeapon(playerid, WEAPON_M4, 240);
    GivePlayerWeapon(playerid, WEAPON_SHOTGUN, 60);
    GivePlayerWeapon(playerid, WEAPON_DEAGLE, 90);
    GivePlayerWeapon(playerid, WEAPON_KNIFE, 1);
    SetPlayerHealth(playerid, 100.0);
    SetPlayerArmour(playerid, 50.0);

    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    if (gMatchFinished)
    {
        return 1;
    }

    gPlayerDeaths[playerid]++;

    if (killerid == INVALID_PLAYER_ID || killerid == playerid)
    {
        return 1;
    }
    if (!IsPlayerConnected(killerid))
    {
        return 1;
    }

    if (gMatchMode == MATCH_MODE_TDM && gPlayerTeam[killerid] == gPlayerTeam[playerid])
    {
        SendClientMessage(killerid, COLOR_YELLOW, "Friendly-fire kills do not count toward the score.");
        return 1;
    }

    gPlayerKills[killerid]++;

    if (gMatchMode == MATCH_MODE_TDM)
    {
        new teamid = gPlayerTeam[killerid];
        if (teamid == TEAM_RED || teamid == TEAM_BLUE)
        {
            gTeamScore[teamid]++;

            new message[96];
            format(message, sizeof(message), "Team score: RED %d - %d BLUE", gTeamScore[TEAM_RED], gTeamScore[TEAM_BLUE]);
            SendClientMessageToAll(COLOR_WHITE, message);

            if (gTeamScore[teamid] >= MATCH_KILL_LIMIT)
            {
                FinishRound();
            }
        }
    }
    else if (gPlayerKills[killerid] >= MATCH_KILL_LIMIT)
    {
        FinishRound();
    }

    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (!strcmp(cmdtext, "/help", true))
    {
        SendClientMessage(playerid, COLOR_YELLOW, "Commands: /stats - show your kills, deaths, and team score.");
        return 1;
    }

    if (!strcmp(cmdtext, "/stats", true))
    {
        new message[128];
        if (gMatchMode == MATCH_MODE_TDM)
        {
            new teamName[8];
            GetTeamName(gPlayerTeam[playerid], teamName, sizeof(teamName));
            format(message, sizeof(message), "Team: %s | Kills: %d | Deaths: %d | Score: %d-%d",
                teamName,
                gPlayerKills[playerid],
                gPlayerDeaths[playerid],
                gTeamScore[TEAM_RED],
                gTeamScore[TEAM_BLUE]);
        }
        else
        {
            format(message, sizeof(message), "Kills: %d | Deaths: %d | First to %d kills wins.",
                gPlayerKills[playerid],
                gPlayerDeaths[playerid],
                MATCH_KILL_LIMIT);
        }
        SendClientMessage(playerid, COLOR_WHITE, message);
        return 1;
    }

    return 0;
}

public MatchTimerTick()
{
    if (gMatchFinished)
    {
        return 1;
    }

    if (gMatchSecondsRemaining > 0)
    {
        gMatchSecondsRemaining--;
    }

    if (gMatchSecondsRemaining == 60 || gMatchSecondsRemaining == 30 || gMatchSecondsRemaining == 10)
    {
        new message[64];
        format(message, sizeof(message), "Match ends in %d seconds.", gMatchSecondsRemaining);
        SendClientMessageToAll(COLOR_YELLOW, message);
    }

    if (gMatchSecondsRemaining == 0)
    {
        FinishRound();
    }
    return 1;
}

public RestartRound()
{
    gTeamScore[TEAM_RED] = 0;
    gTeamScore[TEAM_BLUE] = 0;
    gMatchSecondsRemaining = MATCH_LENGTH_SECONDS;
    gMatchFinished = 0;

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid))
        {
            gPlayerKills[playerid] = 0;
            gPlayerDeaths[playerid] = 0;
            TogglePlayerControllable(playerid, true);
            SpawnPlayer(playerid);
        }
    }

    SendClientMessageToAll(COLOR_GREEN, "A new round has started. Good luck!");
    return 1;
}

stock AssignPlayerTeam(playerid)
{
    if (gMatchMode == MATCH_MODE_DM)
    {
        gPlayerTeam[playerid] = TEAM_NONE;
        SetPlayerTeam(playerid, NO_TEAM);
        SetPlayerColor(playerid, COLOR_WHITE);
        return 1;
    }

    new redPlayers = GetTeamPlayerCount(TEAM_RED, playerid);
    new bluePlayers = GetTeamPlayerCount(TEAM_BLUE, playerid);

    if (redPlayers < bluePlayers)
    {
        gPlayerTeam[playerid] = TEAM_RED;
    }
    else if (bluePlayers < redPlayers)
    {
        gPlayerTeam[playerid] = TEAM_BLUE;
    }
    else
    {
        gPlayerTeam[playerid] = (random(2) == 0) ? TEAM_RED : TEAM_BLUE;
    }

    SetPlayerTeam(playerid, gPlayerTeam[playerid]);
    SetPlayerColor(playerid, (gPlayerTeam[playerid] == TEAM_RED) ? COLOR_RED : COLOR_BLUE);
    return 1;
}

stock GetTeamPlayerCount(teamid, exceptPlayerid)
{
    new count = 0;
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (playerid != exceptPlayerid && IsPlayerConnected(playerid) && gPlayerTeam[playerid] == teamid)
        {
            count++;
        }
    }
    return count;
}

stock ApplyPlayerSpawn(playerid)
{
    new Float:spawnX;
    new Float:spawnY;
    new Float:spawnZ = 15.3746;
    new Float:spawnAngle;

    if (gMatchMode == MATCH_MODE_TDM && gPlayerTeam[playerid] == TEAM_RED)
    {
        if (random(2) == 0)
        {
            spawnX = 1948.0;
            spawnY = 1343.0;
        }
        else
        {
            spawnX = 1951.0;
            spawnY = 1350.0;
        }
        spawnAngle = 90.0;
    }
    else if (gMatchMode == MATCH_MODE_TDM && gPlayerTeam[playerid] == TEAM_BLUE)
    {
        if (random(2) == 0)
        {
            spawnX = 1966.0;
            spawnY = 1343.0;
        }
        else
        {
            spawnX = 1963.0;
            spawnY = 1350.0;
        }
        spawnAngle = 270.0;
    }
    else if (random(2) == 0)
    {
        spawnX = 1948.0;
        spawnY = 1343.0;
        spawnAngle = 90.0;
    }
    else
    {
        spawnX = 1966.0;
        spawnY = 1343.0;
        spawnAngle = 270.0;
    }

    SetPlayerPos(playerid, spawnX, spawnY, spawnZ);
    SetPlayerFacingAngle(playerid, spawnAngle);
    SetCameraBehindPlayer(playerid);
    return 1;
}

stock GetTeamName(teamid, output[], size)
{
    if (teamid == TEAM_RED)
    {
        format(output, size, "RED");
    }
    else if (teamid == TEAM_BLUE)
    {
        format(output, size, "BLUE");
    }
    else
    {
        format(output, size, "DM");
    }
    return 1;
}

stock FinishRound()
{
    if (gMatchFinished)
    {
        return 0;
    }

    gMatchFinished = 1;

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (IsPlayerConnected(playerid))
        {
            TogglePlayerControllable(playerid, false);
        }
    }

    if (gMatchMode == MATCH_MODE_TDM)
    {
        if (gTeamScore[TEAM_RED] > gTeamScore[TEAM_BLUE])
        {
            SendClientMessageToAll(COLOR_RED, "RED team wins the round!");
        }
        else if (gTeamScore[TEAM_BLUE] > gTeamScore[TEAM_RED])
        {
            SendClientMessageToAll(COLOR_BLUE, "BLUE team wins the round!");
        }
        else
        {
            SendClientMessageToAll(COLOR_YELLOW, "The round ended in a draw.");
        }
    }
    else
    {
        new topPlayer = INVALID_PLAYER_ID;
        new topKills = -1;
        new tied = 0;

        for (new playerid = 0; playerid < MAX_PLAYERS; playerid++)
        {
            if (!IsPlayerConnected(playerid))
            {
                continue;
            }

            if (gPlayerKills[playerid] > topKills)
            {
                topKills = gPlayerKills[playerid];
                topPlayer = playerid;
                tied = 0;
            }
            else if (gPlayerKills[playerid] == topKills)
            {
                tied = 1;
            }
        }

        if (topPlayer == INVALID_PLAYER_ID || tied)
        {
            SendClientMessageToAll(COLOR_YELLOW, "The round ended in a draw.");
        }
        else
        {
            new playerName[MAX_PLAYER_NAME + 1];
            new message[96];
            GetPlayerName(topPlayer, playerName, sizeof(playerName));
            format(message, sizeof(message), "%s wins the round with %d kills!", playerName, topKills);
            SendClientMessageToAll(COLOR_GREEN, message);
        }
    }

    SendClientMessageToAll(COLOR_YELLOW, "The next round starts in 8 seconds.");
    SetTimer("RestartRound", ROUND_INTERMISSION_MS, false);
    return 1;
}
