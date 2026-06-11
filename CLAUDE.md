# CLAUDE.md — PrysmosGames

Generated Roblox games only. Hermes pushes to `roblox_games/{game_id}/`.

**Validation:** RoGit pull in Studio, then **Cursor + Roblox Studio MCP** for playtest and runtime fixes. See Prysmo `docs/STUDIO_MCP_OPERATOR.md`.

When editing a game:

- Use Luau file naming: `.server.lua`, `.client.lua`, modules as `.lua`
- Remotes live under `ReplicatedStorage/Remotes/` in the repo tree (no runtime creation)
- Server owns score/state; DataStore on round end
- Replace monetisation placeholders after Creator Dashboard setup

Commit fixes from Cursor during polish; use RoGit push when changes were made inside Studio only.
