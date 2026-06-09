# CLAUDE.md — PrysmosGames

Generated Roblox games only. Hermes pushes to `roblox_games/{game_id}/`.

When editing a game:
- Use Rojo naming: `.server.lua`, `.client.lua`, modules as `.lua`
- Remotes live in `src/ReplicatedStorage/Remotes/`
- Server owns score/state; DataStore on round end
- Replace monetisation placeholders after Creator Dashboard setup

Validate in Roblox Studio via MCP before human publish approval.
