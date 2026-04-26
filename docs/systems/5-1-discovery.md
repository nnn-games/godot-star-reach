# 5-1. Discovery / Codex — 천체 도감 (12 엔트리 Lite B)

> 카테고리: Meta / Collection
> 구현: `scripts/services/discovery_service.gd`, `data/codex_config.tres`

## 1. 시스템 개요

목적지 완료를 **천체/천체계/우주 영역 단위 도감 진행**으로 연결하는 수집형 메타 시스템. 12개 엔트리(Lite B 범위)가 서로 다른 목적지 그룹을 대표하며, 완료한 목적지 수에 따라 섹션 해금 → 팩트 카드 해금 → 엔트리 완성으로 성장.

**책임 경계**
- `EventBus.destination_completed` 구독 → 도감 상태 변화 계산 (NEW / UPDATED / COMPLETE).
- 가장 의미 있는 변화 하나를 선택해 `codex_entry_unlocked` / `codex_entry_updated` / `codex_entry_completed` 시그널 발행.
- **영속 저장 없음**: 모든 상태는 `GameState.completed_destinations` (Set)에서 파생.

**책임 아닌 것**
- 첫도달 뱃지(→ 5-2 Badge)
- 지역 마스터리(→ 2-2 Region)
- 도감 UI 렌더링 (별도)

## 2. 코어 로직

### 2.1 엔트리 구조 (`CodexEntry` Resource)

```gdscript
class_name CodexEntry extends Resource

@export var id: StringName             # "BODY_MARS"
@export var display_name: String       # "Mars"
@export_enum("planet", "moon", "system", "region") var entry_type: String
@export_multiline var summary: String
@export var source_destinations: PackedStringArray = []   # ["D_36", ...]
@export var sections: Array[CodexSection] = []
@export var facts: Array[CodexFact] = []
@export var required_section_ids: PackedStringArray = []
@export var minimum_distinct_destinations: int = 0
```

```gdscript
class_name CodexSection extends Resource
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var destination_ids: PackedStringArray = []   # 빈 배열이면 엔트리 unlock 시 자동 unlock

class_name CodexFact extends Resource
@export var threshold: int
@export_multiline var text: String
```

### 2.2 해금 규칙 (`compute_entry_status`)

각 엔트리에 대해:
1. **unlocked**: `source_destinations` 중 1개 이상 완료.
2. **discovered_count**: `source_destinations` 중 완료한 개수.
3. **unlocked_sections**: 각 섹션 중 `destination_ids` 중 1개 이상 완료 시 해당 섹션 unlocked.
   - 예외: `destination_ids.is_empty()` (Overview 등)은 엔트리가 unlocked이면 자동 unlocked.
4. **unlocked_facts**: `discovered_count >= fact.threshold`인 팩트 카드 수.
5. **is_complete**: `모든 required_section_ids unlocked AND discovered_count >= minimum_distinct_destinations`.

### 2.3 완료 이벤트 변화 계산 (`_on_destination_completed`)

```
1. after_completed = GameState.completed_destinations            # Set, 현재 완료 포함
2. before_completed = after_completed.duplicate()
   before_completed.erase(destination_id)

3. for each entry in entry_order:
     if destination_id not in entry.source_destinations: continue
     before = compute_entry_status(entry, before_completed)
     after  = compute_entry_status(entry, after_completed)

     if not before.is_complete and after.is_complete:           # 우선순위 3
         change = { type = "COMPLETE", entry = entry, ... }
     elif not before.unlocked and after.unlocked:               # 우선순위 2
         change = { type = "NEW", entry = entry, ... }
     elif after.discovered_count > before.discovered_count:     # 우선순위 1
         change = { type = "UPDATED", entry = entry, ... }

4. 우선순위가 가장 높은 변화 1개 선택 (동률이면 entry_order 선순위 우선)

5. 시그널 발행:
   COMPLETE → emit codex_entry_completed(entry_id)
   NEW      → emit codex_entry_unlocked(entry_id)
   UPDATED  → emit codex_entry_updated(entry_id, discovered_count, total)
   섹션 신규 해금 → emit codex_section_unlocked(entry_id, section_id) (변화당 N회)
```

> **하나의 완료가 여러 엔트리에 영향**을 줄 수 있음. 예: `D_16` 완료 시 `REGION_NEAR_EARTH`와 `SYSTEM_EARTH_MOON` 두 엔트리 모두 변화. 우선순위 규칙으로 1개만 "주요 변화"로 보고 (섹션 시그널은 모두 발행).

### 2.4 1차 출시 엔트리 12개 (Lite B)

| Entry ID | 이름 | entry_type | 대표 Region | 섹션 수 | 팩트 수 |
|---|---|---|---|---:|---:|
| REGION_NEAR_EARTH | Near-Earth Space | region | REGION_NEAR_EARTH | 4 | 3 |
| BODY_MOON | Moon | moon | REGION_MOON | 4 | 3 |
| SYSTEM_EARTH_MOON | Earth-Moon System | system | (cross) | 3 | 3 |
| BODY_MARS | Mars | planet | REGION_MARS | 4 | 3 |
| BODY_VENUS | Venus | planet | REGION_VENUS | 3 | 3 |
| BODY_MERCURY | Mercury | planet | REGION_MERCURY_SOLAR | 4 | 3 |
| SYSTEM_ASTEROID_BELT | Asteroid Belt | system | REGION_ASTEROID_BELT | 3 | 3 |
| BODY_JUPITER | Jupiter | planet | REGION_JUPITER | 4 | 3 |
| BODY_EUROPA | Europa | moon | REGION_JUPITER_MOONS | 3 | 3 |
| BODY_SATURN | Saturn | planet | REGION_SATURN | 4 | 3 |
| BODY_TITAN | Titan | moon | REGION_SATURN_MOONS | 3 | 3 |
| BODY_PLUTO | Pluto System | system | REGION_PLUTO_KUIPER | 3 | 3 |

### 2.5 `entry_order` 우선순위

같은 우선순위(둘 다 `UPDATED`)의 변화가 여러 엔트리에서 동시 발생할 때, `CodexConfig.entry_order`에 먼저 등장한 엔트리가 "주요 변화"로 선택됨.

## 3. 정적 데이터 (Config)

### `data/codex_config.tres` (`CodexConfig` Resource)

```gdscript
class_name CodexConfig extends Resource

@export var entries: Array[CodexEntry] = []           # 12개
@export var entry_order: PackedStringArray = []       # 우선순위 결정용
```

### 헬퍼 함수 (`CodexConfig`)

- `get_entry(id: StringName) -> CodexEntry`
- `compute_entry_status(entry: CodexEntry, completed: Dictionary) -> Dictionary`
  - 반환: `{ unlocked, discovered_count, unlocked_sections (PackedStringArray), unlocked_facts (int), is_complete }`
- `compute_summary(completed: Dictionary) -> Dictionary` — `{ total_unlocked, total_complete }`

## 4. 플레이어 영속 데이터 — `user://savegame.json`

**전용 필드 없음**. 파생 데이터 중복 저장 금지 원칙.

소스: `save["completed_destinations"]: Array[String]` (→ 2-1, 2-2와 공유). 로드 시 `GameState.completed_destinations: Dictionary[String, bool]`로 복원.

## 5. 런타임 상태

`DiscoveryService` (autoload):

| 필드 | 용도 |
|---|---|
| `_config: CodexConfig` | 부팅 시 `data/codex_config.tres` 로드 |

상태 캐시 없음 — 매 호출 시 `GameState.completed_destinations`에서 재계산.

## 6. 시그널 (EventBus)

```gdscript
# EventBus.gd
signal codex_entry_unlocked(entry_id: StringName)                              # NEW
signal codex_entry_updated(entry_id: StringName, discovered: int, total: int)  # UPDATED
signal codex_section_unlocked(entry_id: StringName, section_id: StringName)
signal codex_entry_completed(entry_id: StringName)                             # COMPLETE
```

UI(`CodexPanel`)는 위 시그널을 구독해 토스트/배지를 표시. 도감 전체 표시는 `DiscoveryService.get_status()` 메서드를 직접 호출(파생 계산이라 즉시 반환).

## 7. 의존성

**의존**: `GameState` (autoload, `completed_destinations` 조회), `EventBus` (autoload).

**의존받음**:
- `EventBus.destination_completed(destination_id)` — `DestinationService` 또는 `LaunchService` 측에서 발행, `DiscoveryService`가 구독
- `CodexPanel` UI — `codex_*` 시그널 구독 + `DiscoveryService.get_status()` 호출

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/discovery_service.gd` | autoload, 변화 계산 + 시그널 발행 |
| `scripts/data/codex_entry.gd` | `CodexEntry` Resource 클래스 |
| `scripts/data/codex_section.gd` | `CodexSection` Resource 클래스 |
| `scripts/data/codex_fact.gd` | `CodexFact` Resource 클래스 |
| `scripts/data/codex_config.gd` | `CodexConfig` Resource + 계산 함수 |
| `data/codex_config.tres` | 12개 엔트리 정의 |
| `scripts/autoload/event_bus.gd` | `codex_*` 시그널 4종 |
| `scenes/ui/codex_panel.tscn` | 도감 UI |

## 9. 알려진 이슈 / 설계 주의점

1. **파생 상태의 장점과 제약**: 영속 저장 안 하므로 마이그레이션 이슈 없음. 대신 12개 엔트리 전부 매번 재계산 → 완료 이벤트 1회마다 `compute_entry_status`를 엔트리당 2회 호출 (before/after). 12 × 몇 십 목적지 수준이라 비용 무시 가능.
2. **하나의 완료당 "주요 변화" 1개만 보고**: 내부적으로 여러 엔트리 변화가 일어나도 CodexPanel 토스트는 1개만. 섹션 단위 시그널(`codex_section_unlocked`)은 발생한 만큼 모두 발행.
3. **T6 범위 제외**: `INTERSTELLAR` 관련 엔트리는 1차 Lite B 미포함.
4. **Codex vs Region vs Badge 3축 관계**:
   - **Region**: 지역(11개), 첫도달 뱃지 + 마스터리.
   - **Discovery**: 엔트리(12개, Lite B), 섹션 + 팩트 카드.
   - **Badge**: 뱃지 본체(첫도달 14종 + Win 카운트 5종 = 19종).
   - 세 축이 목적지와 다대다 관계로 연결됨. `SYSTEM_EARTH_MOON`처럼 여러 Region에 걸친 엔트리도 존재.
5. **`minimum_distinct_destinations`와 섹션 해금 분리**: 섹션이 모두 열려도 최소 목적지 수를 충족 못하면 `is_complete=false`. 반대 케이스도 가능. "필요한 섹션들 + 최소 고유 개수" 양쪽 모두 만족해야 완성.
