# Player Commands Guide

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

Everything you can type in the server's chat, grouped by what you want to do.

---

## How to use commands

| Form | Example | Note |
|---|---|---|
| Chat with `!` | `!ready` | Everyone sees the command in chat |
| Chat with `/` | `/ready` | **Silent**, only you see the reply |
| Console (`~`) | `sm_ready` | Replace `!` with `sm_` |

**What `< >` and `[ ]` mean**

In this guide, `< >` and `[ ]` only show what goes in that spot. **Don't type the symbols**, replace the whole thing with the value:

| In the guide | Meaning | You type |
|---|---|---|
| `!mix <captain1> <captain2>` | `< >` = required | `!mix vorkyss Feeh` |
| `!roll [number]` | `[ ]` = optional, can be left out | `!roll` or `!roll 20` |

❌ Wrong: `!mix <vorkyss> <Feeh>`

✅ Right: `!mix vorkyss Feeh`

---

## Ready-up (before the round starts)

| Command | What it does |
|---|---|
| `!ready` / `!r` | Marks you as ready. The round starts when everyone is ready |
| `!unready` / `!nr` | Removes your ready status |
| `!toggleready` | Switches between ready and not ready |
| `!hide` / `!show` | Hides or shows the ready-up panel (useful to see other menus) |
| `!return` | Takes you back to the saferoom if you get stuck during ready-up |

## Pause

| Command | What it does |
|---|---|
| `!pause` | Pauses the game |
| `!unpause` / `!ready` | Marks your team as ready to resume. The game resumes when both teams are ready |
| `!unready` / `!nr` | Marks your team as not ready to resume |

> If a player crashes or disconnects during a live round, the game may pause automatically. Once they are back, use `!unpause` / `!ready` to resume.

---

## Teams and queue

| Command | What it does |
|---|---|
| `!spec` / `!s` | Moves you to spectators |
| `!fila` / `!queue` | Shows the waiting queue in order |
| `!vaga` / `!slot` | Claims a slot in the game if it's your turn in the queue |
| `!mix` | Votes to start a mix. Once enough players vote, everyone votes for the captains, and the captains pick the teams through a menu |
| `!mix <captain1> <captain2>` | Starts a vote proposing two captains: `captain1` on survivors and `captain2` on infected. If most players vote **yes**, the mix starts with them |
| `!teamflip` / `!tf` | Randomly picks a team (Survivor or Infected) for you, shown to everyone |
| `!kickspecs` | Starts a vote to kick spectators |

Examples:

```
!mix                           -> vote to start a mix
!mix vorkyss Feeh              -> propose vorkyss and Feeh as captains
!mix "(LoD) Adeilson" Feeh     -> use quotes when the name has spaces or symbols
```

> **About the mix:** both teams must be full and the mix can only start at the beginning of a new game (0 x 0). Captains must be playing (not spectating). There is no mix in 1v1. If someone leaves during a mix, the mix is canceled; doing it a second time gets you **banned for 30 minutes**.

> **About the queue:** slots can only be claimed at the start of a new game and when no mix is running. When a slot opens up, the server tells the next player in line to type `!slot`.

> **Tank alive:** survivors can't switch to spectators while the Tank is alive. Use `!pause` if you really need to change teams.

---

## Votes

| Command | What it does |
|---|---|
| `!match` / `!match <config>` | Starts a vote to load a config. Without a config, opens a menu to choose one. Ex.: `!match zonemod` |
| `!chmatch <config>` | Starts a vote to change to another config |
| `!rmatch` | Starts a vote to turn the current config off |
| `!votecamp` / `!votecampaign` | Opens a menu to vote for a campaign change (official and custom campaigns) |
| `!voteboss <tank> <witch>` | Votes to change the Tank and Witch spawn percentages (ready-up only). `0` = no spawn, `-1` = keep current |
| `!setscores <survivors> <infected>` | Starts a vote to change the match score (players on a team only) |
| `!slots <number>` | Starts a vote to change the number of server slots. Ex.: `!slots 10` |

Available configs: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

---

## Match information

| Command | What it does |
|---|---|
| `!boss` / `!tank` / `!witch` | Shows where the Tank and Witch will spawn (%) and who will be the Tank |
| `!cur` / `!current` | Shows how far the survivors have progressed in the map (%) |
| `!health` / `!bonus` / `!damage` | Shows the current survivor bonus |
| `!mapinfo` | Shows the map's distance and bonus values |
| `!cfg` / `!changelog` | Shows what the current config changes |
| `!lerps` | Lists every player's lerp |
| `!rates` | Lists every player's network settings |

## Stats and ranking

| Command | What it does |
|---|---|
| `!stats` | Survivor stats for the round. Type `!stats help` to see every option |
| `!mvp` | Survivor MVP for the round |
| `!mvpme` | Your own MVP stats |
| `!skill` | Skill stats (skeets, levels, crowns...) |
| `!ff` | Friendly fire stats |
| `!acc` | Accuracy stats |
| `!stats_auto <flags>` | Chooses which stats are shown automatically at the end of the round. `-1` = none, `0` = server default. Type `!stats_auto help` for details |
| `!ranking` | Shows your position in the server ranking |

---

## Spectators

| Command | What it does |
|---|---|
| `!hear` | Chooses whose voice you hear: survivors, infected, spectators only, or everyone. Ex.: `!hear survivors` |
| `!spechud` | Shows or hides the spectator HUD |
| `!tankhud` | Shows or hides the Tank HUD |
| `!cast` | Registers you as a caster (only for authorized casters) |
| `!notcasting` / `!uncast` | Removes you from casters |

---

## In-game

### Infected

| Command | What it does |
|---|---|
| `!warp <1-4>` / `!warp <name>` | While in ghost mode, teleports you to a survivor |

### Tank rock throw

| Command | Key | Throw |
|---|---|---|
| `!overhand` | Reload | Two-handed overhand |
| `!underhand` | Use | Underhand |
| `!overonehand` | M2 | One-handed overhand |

### Survivors

| Command | What it does |
|---|---|
| `!secondary` | Turns on/off switching to the melee weapon when you pick one up |

---

## Fun

| Command | What it does |
|---|---|
| `!coinflip` / `!cf` / `!flip` | Flips a coin (heads or tails) |
| `!roll [number]` / `!picknumber [number]` | Rolls a die. Ex.: `!roll 20` |

---

## Server rules

- **Friendly fire:** repeatedly damaging your own team gets you kicked automatically, and the game is paused.
- **AFK:** during ready-up, players who stay AFK for too long are moved to spectators when someone else is waiting to play.
- **Lerp:** if your lerp is outside the allowed range, the server shows the commands to fix it. Paste them into your console:

```
cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100
```

Need help? Talk to an admin on the server.
