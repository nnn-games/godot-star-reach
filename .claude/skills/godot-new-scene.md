---
name: godot-new-scene
description: Create a minimal .tscn file at the given path with a single root node of the requested type. Usage `/godot-new-scene <path> [RootNodeType]`. Attaches a matching .gd if requested.
---

# /godot-new-scene

사용법: `/godot-new-scene <path> [RootNodeType] [--with-script]`

예:
- `/godot-new-scene scenes/ui/hud.tscn Control --with-script`
- `/godot-new-scene scenes/game/miner.tscn Node2D`

## 작업 절차

1. `path`, `RootNodeType`(기본 `Node2D`), `--with-script` 플래그 파싱.
2. `star-reach/` 하위 경로인지 검증. 파일 존재 시 중단.
3. 루트 노드 이름은 파일명 `PascalCase` 변환.
4. 새 UID는 `uid://` 접두에 유일한 10자 base32 문자열 생성 (예: `uid://bq7m3k9xa2`).
5. `.tscn` 내용:

```
[gd_scene format=3 uid="uid://{{new_uid}}"]

[node name="{{RootName}}" type="{{RootNodeType}}"]
```

6. `--with-script` 지정 시:
   - 같은 경로에 `.gd` 파일을 `/godot-new-script` 로직으로 생성 (BaseClass = RootNodeType).
   - `.tscn`에 `[ext_resource type="Script" path="..." id="1_main"]` + 루트 노드에 `script = ExtResource("1_main")` 추가.
7. 생성 후 Godot 에디터에서 임포트 새로고침 필요함을 안내.

## 주의

- 기존 씬의 UID 규약을 유지하기 위해 **새 UID만** 생성. 다른 파일의 UID 건드리지 말 것.
- 복잡한 씬(자식 노드 다수, 리소스 참조)은 이 스킬로 만들지 말고 `godot-scene-surgeon` 에이전트에 위임.
