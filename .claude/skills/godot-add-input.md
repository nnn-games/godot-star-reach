---
name: godot-add-input
description: Add an InputMap action to project.godot. Usage `/godot-add-input <action_name> <key|mouse|joypad>[,<second>,...]`. Updates the [input] section with correctly formatted InputEvent entries.
---

# /godot-add-input

사용법: `/godot-add-input <action_name> <event>[,<event>,...]`

예:
- `/godot-add-input ui_click mouse_left`
- `/godot-add-input click_miner key_space,mouse_left`
- `/godot-add-input toggle_menu key_escape`

## 이벤트 문법

- 키보드: `key_<name>` — `key_space`, `key_escape`, `key_enter`, `key_a`, `key_f1` ...
- 마우스: `mouse_left` / `mouse_right` / `mouse_middle`
- 조이패드 버튼: `pad_<n>` (JOY_BUTTON_n)

## 작업 절차

1. `action_name`이 `snake_case`인지 검증. `ui_` 접두는 Godot 기본 액션과 충돌 가능 — 경고 후 확인.
2. `star-reach/project.godot` 의 `[input]` 섹션 확인. 없으면 새 섹션 추가.
3. 동일 `action_name` 이미 존재 시 중단하고 기존 항목 출력.
4. 각 이벤트를 다음 포맷으로 변환:

- 키보드:
```
{"deadzone": 0.5, "events": [
  Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":{{KEY_CODE}},"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]}
```

- 마우스 버튼:
```
Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"button_index":{{MOUSE_INDEX}},"pressed":false,...)
```

5. 정확한 직렬화 포맷은 작업 직전에 기존 `[input]` 항목을 한 번 읽어 **현재 Godot 4.6 출력 그대로** 모방. 수동으로 외우려 하지 말 것.
6. 추가 후 `project.godot` 끝 줄 개행 유지. 검증은 `/godot-run check` 로 수행.

## 주의

- 이 포맷은 Godot 버전 사이에 바뀔 수 있음. 에디터가 자동 저장한 라인을 **복사-변형**하는 방식이 가장 안전합니다.
- 여러 액션을 동시에 추가해야 하면 에디터에서 한 번 저장 → 포맷 관찰 → AI 복제 순서 권장.
