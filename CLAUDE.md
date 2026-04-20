# godot-star-reach — Repository Guide

2D 증분 시뮬레이터(Incremental Simulator) 장르 게임 **StarReach**의 개발 저장소입니다. 개발은 AI(Claude Code)가 씬·스크립트·프로젝트 설정을 모두 전담하는 **Agent-Driven Development** 방식으로 진행됩니다.

> 기획서는 작성 중이므로, 이 문서는 장르/엔진 일반 규범만 명시합니다. 기획 확정 후 `star-reach/CLAUDE.md`에 게임별 규칙을 추가합니다.

## 디렉터리 구조

```
godot-star-reach/
├── CLAUDE.md                # ← 이 문서 (루트 지침)
├── star-reach/              # Godot 4.6 프로젝트 루트
│   ├── CLAUDE.md            # Godot 내부 코드/씬 규칙
│   ├── project.godot
│   ├── main.tscn
│   └── ...
├── study/                   # 학습/리서치 메모 (코드 X)
└── .claude/                 # Claude Code 설정·스킬·에이전트
    ├── settings.json
    ├── skills/
    └── agents/
```

**Godot 프로젝트 루트는 `star-reach/`입니다.** 엔진이나 `godot` CLI를 실행할 때는 해당 디렉터리를 작업 경로로 지정해야 합니다.

## 개발 환경

- **Godot 4.6** (GDScript / Standard 버전)
- **렌더러**: GL Compatibility (Windows는 D3D12)
- **물리**: Jolt Physics (2D 게임이지만 프로젝트 기본값 유지)
- **OS**: Windows 11, 셸은 Git Bash (이 환경에서는 Unix 경로 사용)

## Agent-Driven 개발 워크플로우

AI가 전담합니다. 사용자는 자연어 지시 → Godot 에디터에서 F5로 검증만 합니다.

1. **지시 수신**: 사용자가 기능/버그를 자연어로 전달.
2. **설계**: AI가 필요한 노드 트리, 스크립트, 리소스, 오토로드, InputMap을 설계.
3. **직접 작성**: AI가 `.gd` / `.tscn` / `.tres` / `project.godot`을 텍스트 편집으로 직접 수정.
   - `.tscn` 편집은 `godot-scene-surgeon` 에이전트에 위임하면 UID/ExtResource 정합성을 안전하게 유지합니다.
   - 복잡한 노드 구성은 **코드로 동적 생성**(`Node.new()` + `add_child`)을 우선 검토. 텍스트 씬 편집이 위험한 규모일 때의 안전장치입니다.
4. **사용자 검증**: 에디터가 파일 변경을 리로드하면 F5 실행 → 결과/에러 로그를 AI에게 전달.
5. **자가 수정**: AI가 에러 로그를 읽고 수정.

자세한 내용: [study/agent_driven_workflow.md](study/agent_driven_workflow.md)

## 2D 증분 시뮬레이터 장르 — 일반 지침

기획 확정 전 기본값으로 따르는 장르 컨벤션입니다. 구현 시 이를 선제적으로 고려하세요.

### 코어 루프
- **생성(Generate) → 소비(Spend) → 강화(Upgrade) → (선택) 프레스티지(Prestige)** 의 고리를 깨지 않습니다.
- 모든 재화는 `rate/second` 축적 모델로 표현 가능해야 합니다. 불연속 이벤트(클릭 등)도 내부적으로는 누적 틱에 더합니다.

### 데이터 주도 설계 (Data-Driven)
- 생성기(Generator), 업그레이드, 재화, 프레스티지 노드 등 **모든 정적 밸런싱 데이터는 `Resource`(`.tres`)로 분리**합니다. 하드코딩 금지.
- 곡선(비용/효율)은 함수 또는 커브 리소스로 표현. `base * growth^level` 형태를 기본값으로.

### 상태/UI 분리
- 게임 상태는 `GameState` 오토로드 싱글턴이 소유. UI는 **읽기/신호 구독만** 합니다.
- 상태 → UI는 `signal`, UI → 상태는 메서드 호출. UI 노드가 `GameState` 필드를 직접 쓰는 패턴은 금지.

### 숫자 처리
- GDScript의 `float`는 64-bit. 일반 증분 범위(~1e308)에서는 충분합니다.
- 표시용은 **과학 표기 / SI 접두어 포맷터**를 유틸리티로 공용화. UI에서 매번 재구현 금지.
- `1e308` 초과 스케일이 기획에 들어오면 커스텀 BigNumber(`mantissa + exponent`) 구조로 전환 — 기획 확정 시 재검토.

### 시간/틱
- 메인 루프는 `_process(delta)`에서 **누적 시간**으로 계산. 프레임 드롭에 안전해야 합니다.
- 물리/결정적 로직은 `_physics_process`. 그 외 경제 계산은 `_process` 또는 별도 `Timer`.

### 저장/로드
- 저장 포맷: `user://savegame.json` (JSON, `FileAccess` + `JSON.stringify`).
- **스키마 버전 필드 필수** (`"version": 1`). 로드 시 마이그레이션 훅을 통과.
- 저장 트리거: N초(기본 10s) 주기 + `NOTIFICATION_WM_CLOSE_REQUEST` + 수동 저장 버튼.

### 오프라인 진행
- 저장 시 `Time.get_unix_time_from_system()` 기록, 로드 시 델타 계산.
- **캡 필수**: 최대 오프라인 시간(예: 8h)을 넘기면 잘라냄. UI에서 "오프라인 중 획득" 요약을 보여줌.

### 이벤트 버스
- 느슨한 결합이 필요한 전역 이벤트는 `EventBus` 오토로드의 전용 시그널로 통과시킵니다. 노드 간 직접 참조 체인은 깊게 만들지 않습니다.

## 코딩/작업 규칙

- **GDScript는 타입 힌트 필수** — 매개변수, 반환형, 변수 선언 모두. 자세한 규칙은 `star-reach/CLAUDE.md` 참조.
- `class_name`은 재사용 가능한 타입에만 부여. 일회성 씬 스크립트에는 불필요.
- 주석은 **왜(Why)** 만 답니다. 무엇을(What) 하는지는 이름으로 드러내세요.
- 기능 범위를 넘는 리팩터링/추상화 금지. 요청된 일만 정확히 합니다.

## 유용한 명령

```bash
# Godot CLI (PATH에 godot 등록 필요)
godot --path star-reach                          # 에디터 실행
godot --path star-reach --headless --quit        # 프로젝트 임포트/검증만
godot --path star-reach --check-only <script>    # 스크립트 신택스 체크
godot --path star-reach --headless -s <script>   # 스크립트 실행 (헤드리스 테스트)
```

PATH에 없다면 `C:\Godot\Godot_v4.6-stable_win64.exe` 같은 절대 경로를 사용하거나, 환경변수에 등록하세요.

## 추가 지침

- Godot 엔진 내부(노드 타입, API, 씬 포맷 등)에 대한 세부 규칙은 [`star-reach/CLAUDE.md`](star-reach/CLAUDE.md)를 따릅니다.
- 슬래시 커맨드는 `.claude/skills/` 에 정의되어 있습니다 (`/godot-new-script`, `/godot-new-scene`, `/godot-add-autoload`, `/godot-add-input`, `/godot-run`).
- `.tscn` 파일 수술은 `godot-scene-surgeon` 서브에이전트에 위임하세요.
