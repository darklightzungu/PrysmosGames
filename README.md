# PrysmosGames



Roblox game source of truth (v3). Hermes generates projects here — no manual v2 migration.



## Workflow



```text

Hermes PR → RoGit pull in Studio → Cursor + Studio MCP playtest → human publish

```



Infra and operator docs: https://github.com/darklightzungu/Prysmo (`docs/STUDIO_MCP_OPERATOR.md`)



## Layout



```text

roblox_games/{GameName}_{pipelineId}/

  ServerScriptService/

  StarterPlayer/StarterPlayerScripts/

  ReplicatedStorage/Remotes/

```



Flat Studio service paths (RoGit-friendly). Optional `default.project.json` per game is not required for CI.



## Rules



- Remotes defined in repo tree, not at runtime

- CI runs **Selene** Luau lint on PR (`luau-lint.yml`) — no Rojo build

- Playtest pass requires **Cursor + Studio MCP**, not Hermes alone

- Concepts replay through Hermes once pipeline baseline passes


