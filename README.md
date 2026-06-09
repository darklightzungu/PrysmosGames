# PrysmosGames

Roblox game source of truth (v3). Hermes generates projects here — no manual v2 migration.

## Layout

```text
roblox_games/{GameName}_{pipelineId}/
  default.project.json
  src/
    ReplicatedStorage/Remotes/
    ServerScriptService/
    StarterPlayerScripts/
```

## Rules

- One Rojo project per game folder
- Remotes defined in Rojo, not at runtime
- CI validates Luau on PR
- Concepts replay through Hermes once pipeline baseline passes

Infra lives in https://github.com/darklightzungu/Prysmo
