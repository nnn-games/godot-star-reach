---
name: godot-new-script
description: Create a new GDScript file at the given path with the project's enforced template (typed, ordered sections). Arg is the target path relative to star-reach/, optionally followed by a base class (defaults to Node).
---

# /godot-new-script

사용법: `/godot-new-script <path> [BaseClass]`

예: `/godot-new-script scripts/systems/economy.gd Node`

## 작업 절차

1. `args`를 파싱해 `path`와 선택적 `BaseClass`(기본값 `Node`) 추출.
2. 경로가 `star-reach/` 하위인지 확인. 아니면 사용자에게 수정 제안.
3. 파일이 이미 존재하면 **덮어쓰지 말고** 중단하고 사용자에게 확인 요청.
4. `star-reach/CLAUDE.md`의 **파일 구성 순서**를 따르는 스켈레톤 작성:

```gdscript
class_name {{PascalCase 파일명}}
extends {{BaseClass}}

## {{파일 한 줄 설명 — 사용자에게 한 번 더 확인}}

# --- Signals ---

# --- Enums & Constants ---

# --- Exports ---

# --- Public State ---

# --- Private State ---

# --- Lifecycle ---
func _ready() -> void:
    pass

# --- Public API ---

# --- Private ---
```

5. `class_name`은 재사용 가능한 타입일 때만 유지. 씬 전용 스크립트면 사용자에게 제거 제안.
6. 작성 후 파일 경로와 다음 단계(씬 첨부 여부)를 안내.

## 주의

- 타입 힌트 미표기 금지.
- `print()` 대신 `print_debug()` 유도.
- 큰 `if/elif` 체인이 예상되면 `match` 먼저 제안.
