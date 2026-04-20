---
name: godot-add-autoload
description: Register a new autoload singleton in project.godot. Usage `/godot-add-autoload <SingletonName> <script_path>`. Creates the script if missing and inserts the [autoload] entry in the correct section.
---

# /godot-add-autoload

사용법: `/godot-add-autoload <SingletonName> <script_path>`

예: `/godot-add-autoload EventBus scripts/autoload/event_bus.gd`

## 작업 절차

1. `SingletonName`이 `PascalCase`인지 검증. 아니면 변환 제안.
2. `star-reach/project.godot` 을 읽고 `[autoload]` 섹션 위치 확인. 없으면 `[application]` 뒤에 새 섹션 생성.
3. 동일 이름이 이미 등록되어 있으면 중단.
4. 스크립트 파일이 없으면 `/godot-new-script` 절차로 생성 (BaseClass = `Node`).
5. `project.godot`에 다음 라인 추가:

```
[autoload]

{{SingletonName}}="*res://{{script_path}}"
```

- 접두 `*`는 활성화 의미. 비활성으로 두려면 사용자가 명시 요청한 경우만 생략.

6. `star-reach/CLAUDE.md`의 "오토로드 기본 세트" 표에 4개 초과 시 **정당성 재검토** 규칙 적용 — 현재 개수를 확인하고 초과 시 사용자에게 확인.
7. Godot 에디터가 실행 중이라면 재시작 필요함을 안내 (오토로드는 즉시 리로드 안 됨).

## 주의

- `.godot/` 내 캐시는 **절대 편집하지 않음** — 엔진이 재생성.
- 기존 오토로드 라인의 순서를 바꾸지 말 것 (의존성 순서에 영향).
