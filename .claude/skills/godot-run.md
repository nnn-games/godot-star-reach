---
name: godot-run
description: Run Godot CLI commands against the star-reach project. Modes: check (import+validate headless), editor (open), script (headless execute). Usage `/godot-run <mode> [target]`.
---

# /godot-run

사용법:
- `/godot-run check` — 프로젝트 임포트 + 에러 확인 (헤드리스, 즉시 종료)
- `/godot-run editor` — 에디터 실행
- `/godot-run script <path>` — 헤드리스에서 스크립트 실행
- `/godot-run syntax <path>` — 단일 스크립트 신택스 체크

## 작업 절차

1. `godot` 명령이 PATH에 있는지 확인. 없으면 사용자에게 등록 또는 절대 경로 제공 요청 (예: `C:\Godot\Godot_v4.6-stable_win64.exe`).
2. 모드별 명령 실행:

```bash
# check
godot --path star-reach --headless --quit 2>&1

# editor (백그라운드)
godot --path star-reach

# script
godot --path star-reach --headless -s <path>

# syntax
godot --path star-reach --check-only <path>
```

3. 종료 코드 확인. 0 이 아니면 출력 전체를 사용자에게 보여주고 수정 제안.
4. `check` 모드에서 `ERROR:` / `WARNING:` 라인을 강조 표시.

## 주의

- 에디터가 이미 열려 있으면 `editor` 모드는 **중복 실행** 주의. 사용자에게 먼저 닫을지 확인.
- `--headless` 실행 결과의 stderr는 경고를 포함 — exit code 0이어도 경고 확인 필수.
- 스크립트 실행은 씬 트리 없이 `static func main()` 류 진입점이 필요. 기존 테스트 러너 `scripts/tests/run_all.gd` 가 있으면 그것을 사용.
