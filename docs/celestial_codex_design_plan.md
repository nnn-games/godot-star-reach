# 천체 도감 기능 기획안 (추천방향 B 확정안)

> 작성일: 2026-04-24
> 확정 방향: `docs/celestial_codex_plan.md`의 `추천 방향 B: 천체 중심 + 탐사 진행도` 채택
> 목적: 발사 목적지 도달 성공을 `천체/천체계/우주 영역 도감` 해금과 `탐사 진행도` 축적으로 연결하는 실제 서비스 기획안을 확정한다.
> 기준 구현 (Godot 4.6): `scripts/services/destination_service.gd`, `scripts/autoload/save_system.gd`, `scripts/autoload/event_bus.gd`, `scenes/ui/global_hud.tscn`, `scenes/ui/win_screen.tscn`
> 관련 문서: `docs/celestial_codex_plan.md`, `docs/destination_config.md`, `docs/rocket_launch_implementation_spec.md`

## 1. 확정 결정

이 기능의 확정 방향은 아래와 같다.

- 도감 엔트리는 `목적지`가 아니라 `천체 / 천체계 / 우주 영역` 단위로 묶는다.
- 하나의 엔트리 안에서 `탐사 진행도`를 누적한다.
- 플레이어는 같은 천체 계열의 여러 목적지를 성공하면서 `개요 -> 하위 섹션 -> 심화 정보 -> 완성` 순으로 엔트리를 발전시킨다.
- 도감은 강제 열람이 아니라 `해금 알림 + 선택 열람` 구조로 제공한다.

한 줄 정의:

> "발사 성공은 단발성 숫자 보상으로 끝나지 않고, 같은 천체를 더 깊게 아는 수집형 메타 진행으로 이어진다."

## 2. 왜 방향 B를 채택하는가

방향 A는 구현이 단순하고 빠르지만, 목적지 반복 도전의 의미를 충분히 만들지 못한다.  
방향 B는 초기 설계가 더 복잡하지만 아래 가치를 만든다.

- 같은 천체를 여러 번 가는 이유가 생긴다.
- `도달 성공 -> 새 정보 축적`의 구조가 반복 플레이와 잘 맞는다.
- 완성률, 세트 수집, 미션으로 확장하기 좋다.
- 발사 목적지 목록이 많아져도 도감 UI는 상대적으로 안정적으로 유지된다.

대신 아래 위험이 있으므로 설계 원칙으로 통제한다.

- 단순 반복 노가다처럼 느껴질 수 있다.
- UI가 복잡해질 수 있다.
- 콘텐츠 제작량이 늘어난다.

이 문서의 핵심은 위 3개 리스크를 억제한 `가벼운 B안`을 실제 서비스 수준으로 정의하는 것이다.

## 3. 제품 목표와 비목표

## 3.1 목표

- 발사 성공의 감정적 보상을 강화한다.
- 목적지 이름을 단순 단계가 아니라 의미 있는 탐사 대상으로 느끼게 한다.
- 우주 테마를 이 게임의 차별점으로 고정한다.
- 장기적으로 수집률, 완성률, 미션, 배지와 연결 가능한 메타 축을 만든다.

## 3.2 비목표

- 긴 백과사전형 읽기 기능을 만드는 것이 목적이 아니다.
- 도감 열람을 강제해 플레이 템포를 늦추는 것이 목적이 아니다.
- 도감 해금을 직접적인 파워 상승 수단으로 만드는 것이 목적이 아니다.
- 출시 시점에 100개 목적지 전부를 개별 문서형 콘텐츠로 만드는 것이 목적이 아니다.

## 4. 플레이 경험 정의

## 4.1 핵심 경험

1. 플레이어가 목적지 도달에 성공한다.
2. 서버가 해당 목적지와 연결된 도감 엔트리를 확인한다.
3. `신규 엔트리 해금` 또는 `기존 엔트리 탐사 진행도 증가`를 기록한다.
4. `WinScreen`에서 결과 보상과 함께 도감 변화 요약을 보여준다.
5. 플레이어는 `View Codex` 버튼으로 즉시 진입하거나, 나중에 `GlobalHUD`에서 다시 연다.
6. 도감 화면에서 새로 열린 섹션과 아직 남은 탐사 목표를 확인한다.
7. 플레이어는 "다음엔 같은 천체의 다른 목적지를 가야겠다"는 동기를 갖게 된다.

## 4.2 감정 곡선

- 첫 성공: "새 천체를 발견했다"
- 같은 천체의 다른 목적지 성공: "이 천체를 더 깊게 탐사했다"
- 섹션 완성: "이 천체의 중요한 특징을 이해했다"
- 엔트리 완성: "이 천체군 탐사를 끝냈다"

즉, B안은 `해금`보다 `축적`의 재미를 추가하는 구조다.

## 5. 핵심 설계 원칙

## 5.1 좋은 방향

- `진행도는 같은 목적지 반복이 아니라 서로 다른 목적지 성공`으로 쌓는다.
- `섹션 기반 진행`을 사용한다. 단순 `% 카운트`만 보여주지 않는다.
- `요약 먼저, 상세는 선택` 구조를 유지한다.
- `서버는 해금 판정`, `클라이언트는 콘텐츠 렌더`로 역할을 분리한다.
- `한 엔트리 = 하나의 대표 주제`를 유지한다.

## 5.2 피해야 할 방향

- 동일 목적지를 반복 성공하면 진행도가 계속 오르는 구조
- 해금 즉시 장문 팝업을 강제하는 구조
- 도감 완성이 성공률/XP 배율에 직접 영향을 주는 구조
- 엔트리마다 UI 구조가 전부 달라지는 구조
- 목적지 개수만큼 도감 문서를 늘리는 구조

## 6. 도감 엔티티 정의

## 6.1 용어

- `Destination`: 현재 게임의 발사 목표 데이터
- `CodexEntry`: 도감의 기본 단위
- `ExplorationSection`: 엔트리 내부의 탐사 섹션
- `FactTier`: 탐사 진척에 따라 추가 해금되는 짧은 심화 정보
- `Completion`: 엔트리 완성 상태

## 6.2 왜 "천체" 대신 "천체/천체계/우주 영역"인가

현재 목적지 데이터에는 아래가 섞여 있다.

- 단일 천체: 달, 화성, 금성, 수성, 명왕성
- 위성: 유로파, 타이탄, 카론
- 천체계/환경: 지구-달 라그랑주, 소행성대, 성간 매질

따라서 UI 명칭은 `천체 도감`으로 유지하되, 데이터 단위는 아래 4종을 허용한다.

- `planet`
- `moon`
- `system`
- `region`

이렇게 해야 현재 목적지 구성과 자연스럽게 맞물린다.

## 7. 해금 및 진행도 규칙

## 7.1 기본 규칙

- 플레이어가 연결된 목적지 중 하나를 처음 성공하면 해당 `CodexEntry`가 해금된다.
- 같은 엔트리에 연결된 서로 다른 목적지를 성공하면 `discoveredDestinationIds`가 누적된다.
- 각 `ExplorationSection`은 특정 목적지 묶음과 연결된다.
- 섹션 연결 목적지 중 1개 이상을 성공하면 해당 섹션이 해금된다.
- 엔트리 완성은 `필수 섹션 전부 해금 + 핵심 목적지 수 충족`으로 판정한다.

## 7.2 중복 처리 원칙

- 같은 목적지를 여러 번 성공해도 도감 진행도는 한 번만 카운트한다.
- 도감은 `distinct destination` 수집형 구조로 간다.
- 반복 성공은 Credit/Fame에는 의미가 있어도 도감 진척에는 직접 의미를 주지 않는다.

이 원칙이 없으면 B안이 쉽게 `반복 파밍 숙제`로 변한다.

## 7.3 FactTier 규칙

`FactTier`는 장문 본문이 아니라 짧은 추가 팩트 카드 해금용이다.

- 엔트리 첫 해금 시: 요약 + 기본 팩트 1개
- 서로 다른 관련 목적지 2개 성공: 추가 팩트 1개
- 서로 다른 관련 목적지 4개 성공: 추가 팩트 1개
- 엔트리 완성 시: 마무리 팩트 1개 또는 기념 문구

초기 출시에서는 엔트리당 최대 3~4개 팩트 카드면 충분하다.

## 7.4 완성 판정 규칙

권장 규칙:

- `Entry Unlocked`: 관련 목적지 1개 이상 성공
- `Section Unlocked`: 해당 섹션 연결 목적지 1개 이상 성공
- `Entry Complete`: 필수 섹션 전부 해금 + 엔트리별 최소 탐사 수 충족

예시:

- `Mars` 엔트리
  - `Overview` 해금: 화성 관련 목적지 첫 성공
  - `Surface` 해금: D_36~D_40 중 1개 이상
  - `Moons` 해금: D_53 또는 D_54
  - `Entry Complete`: `Surface`, `Moons` 해금 + 화성 계열 서로 다른 목적지 4개 이상

## 8. 엔트리 구조

## 8.1 기본 구조

모든 엔트리는 아래 공통 구조를 갖는다.

1. 헤더
2. 요약 카드
3. 탐사 섹션 목록
4. 관련 목적지 목록
5. 팩트 카드
6. 진행도/완성률

## 8.2 헤더 구성

- 엔트리 이름
- 분류(`Planet`, `Moon`, `System`, `Region`)
- 티어 배경색 또는 도감 카테고리 색상
- 대표 아이콘 또는 대표 이미지
- 상태 배지

상태 배지 예시:

- `NEW`
- `UPDATED`
- `COMPLETE`

## 8.3 탐사 섹션 템플릿

초기 버전에서는 섹션 타입을 아래 템플릿 중 하나로 제한한다.

- `Overview`
- `Surface / Geography`
- `Orbit / Ring / Atmosphere`
- `Moons / Satellite`
- `Resources / Deep Facts`
- `Exploration Record`

이렇게 표준화해야 운영과 로컬라이징 비용이 관리된다.

## 9. 실제 엔트리 예시

## 9.1 화성 엔트리 예시

`BODY_MARS`

- 대표 목적지: `D_36`, `D_37`, `D_38`, `D_39`, `D_40`, `D_53`, `D_54`
- 해금 조건: 위 목적지 중 1개 이상 첫 성공
- 섹션 구성:
  - `Overview`: 첫 해금 즉시
  - `Surface`: `D_36`, `D_37`, `D_38`, `D_40`
  - `Polar`: `D_39`
  - `Moons`: `D_53`, `D_54`
  - `Deep Facts`: 화성 계열 서로 다른 목적지 4개 이상
- 완성 조건:
  - `Surface`, `Polar`, `Moons` 해금
  - 화성 계열 서로 다른 목적지 4개 이상 성공

플레이어 체감:

- 첫 화성 도달로 엔트리 개방
- 다음엔 "표면 지형 더 가볼까?", "포보스/데이모스도 가야 완성되겠네?"가 된다

## 9.2 달 엔트리 예시

`BODY_MOON`

- 대표 목적지: `D_21`, `D_27`, `D_28`, `D_31`, `D_34`
- 섹션 구성:
  - `Overview`
  - `Surface Landing`
  - `Lava Tube / Resources`
  - `Orbit / Gateway`
- 완성 조건:
  - 필수 섹션 3개 해금
  - 달 관련 서로 다른 목적지 4개 이상 성공

## 9.3 목성 엔트리 예시

`BODY_JUPITER`

- 대표 목적지: `D_56`, `D_61`, `D_72`, `D_75`
- 섹션 구성:
  - `Overview`
  - `Atmosphere`
  - `Rings`
  - `Magnetosphere`
- 별도 위성 엔트리:
  - `BODY_EUROPA`
  - 필요 시 후속으로 `BODY_IO`, `BODY_GANYMEDE`, `BODY_CALLISTO`

## 10. 1차 출시 범위

## 10.1 출시 철학

출시 시점부터 아키텍처는 B안으로 가되, 콘텐츠 양은 `Lite B`로 제한한다.

`Lite B`의 의미:

- 엔트리 내부 진행도는 있다.
- 섹션은 있다.
- 하지만 엔트리당 섹션 수와 텍스트 양은 제한한다.
- 갤러리, 음성, 긴 도해 설명은 넣지 않는다.

## 10.2 권장 출시 수량

- 엔트리 수: `12개`
- 엔트리당 섹션 수: `3~4개`
- 엔트리당 팩트 카드: `3개`
- 신규 알림: `WinScreen` 카드 1개 + HUD 배지 1개
- 현재 gameplay 직접 연동 범위: `T1 ~ T5`
- `T6 성간 우주`는 콘텐츠 풀로 유지하되, 1차 실장 범위에서는 제외

## 10.3 1차 출시 추천 엔트리

| 엔트리 ID | 표시명 | 타입 | 대표 연결 목적지 예시 | 초기 섹션 구상 |
|---|---|---|---|---|
| `REGION_NEAR_EARTH` | Near-Earth Space | `region` | `D_07`, `D_13`, `D_14`, `D_15` | `Overview`, `Orbit`, `Radiation`, `Lagrange` |
| `BODY_MOON` | Moon | `moon` | `D_21`, `D_27`, `D_28`, `D_31`, `D_34` | `Overview`, `Surface`, `Resources`, `Orbit` |
| `SYSTEM_EARTH_MOON` | Earth-Moon System | `system` | `D_16`, `D_20`, `D_31` | `Overview`, `Lagrange`, `Gateway` |
| `BODY_MARS` | Mars | `planet` | `D_36`, `D_38`, `D_39`, `D_53`, `D_54` | `Overview`, `Surface`, `Polar`, `Moons` |
| `BODY_VENUS` | Venus | `planet` | `D_41`, `D_42`, `D_43` | `Overview`, `Highlands`, `Cloud Layer` |
| `BODY_MERCURY` | Mercury | `planet` | `D_44`, `D_45`, `D_52` | `Overview`, `Impact Basin`, `Polar Ice`, `Perihelion` |
| `SYSTEM_ASTEROID_BELT` | Asteroid Belt | `system` | `D_46`, `D_47`, `D_48`, `D_49`, `D_50`, `D_51` | `Overview`, `Major Bodies`, `Sample Return` |
| `BODY_JUPITER` | Jupiter | `planet` | `D_56`, `D_61`, `D_72`, `D_75` | `Overview`, `Atmosphere`, `Rings`, `Magnetosphere` |
| `BODY_EUROPA` | Europa | `moon` | `D_58` | `Overview`, `Ice Shell`, `Subsurface Ocean` |
| `BODY_SATURN` | Saturn | `planet` | `D_62`, `D_63`, `D_73` | `Overview`, `Atmosphere`, `Rings`, `Hexagon` |
| `BODY_TITAN` | Titan | `moon` | `D_64` | `Overview`, `Atmosphere`, `Methane Sea` |
| `BODY_PLUTO` | Pluto System | `system` | `D_76`, `D_77` | `Overview`, `Surface`, `Charon` |

주의:

- 위 표는 1차 출시용 대표 구성이다.
- 전체 목적지와의 최종 매핑 표는 후속 데이터 작업에서 별도로 확정한다.
- 1차는 "모든 목적지 수용"보다 "핵심 주제 묶음 완성"이 우선이다.

## 10.4 첫 도달 뱃지와 지역 마스터리

도감과 별도로 아래 보상 레이어를 함께 가져간다.

- `Region Arrival Badge`
  - 해당 지역 계열 목적지를 처음 하나라도 성공하면 지급
  - 기념용 1회성 보상

- `Region Mastery`
  - 같은 지역의 `서로 다른 목적지`를 반복 성공하며 누적
  - 같은 목적지 반복 성공은 기본 마스터리에 반영하지 않음
  - 보상은 칭호, 패치, 프레임, 발사 연출 코스메틱 등 표현형 보상 위주

권장 출시 순서:

1. 1차 출시: `도감 + 첫 도달 뱃지`
2. 1.1차 확장: `지역 마스터리`

이렇게 나누면 초기 범위를 과도하게 키우지 않으면서도, 반복 탐사에 대한 장기 성취 루프를 미리 설계에 포함할 수 있다.

## 11. UX 기획

## 11.1 진입점

- `WinScreen` 내 `NEW CODEX ENTRY` 또는 `CODEX UPDATED` 카드
- `GlobalHUD` 좌측 기능 버튼에 `CDX`
- 추후 `DestinationPanel` 내 관련 도감 미리보기

## 11.2 WinScreen 노출 규칙

승리 직후에는 도감 본문을 강제 노출하지 않는다. 대신 아래 형태로 요약 카드만 보여준다.

- 신규 엔트리 해금 시: `NEW CODEX ENTRY`
- 기존 엔트리 갱신 시: `CODEX UPDATED`
- 섹션 해금 시: `New Section Unlocked`
- 엔트리 완성 시: `ENTRY COMPLETE`

카드 정보:

- 엔트리명
- 이번에 열린 섹션명 1~2개
- 진행도 변화 예시 `2/4 Sections`
- `View Codex` 버튼

## 11.3 도감 패널 구조

권장 구조는 2단이다.

1. 좌측 리스트
2. 우측 상세 패널

좌측 리스트 표시 항목:

- 엔트리명
- 타입 아이콘
- 상태 배지(`NEW`, `UPDATED`, `COMPLETE`)
- 진행도 바

우측 상세 표시 항목:

- 헤더
- 2~3줄 요약
- 섹션 카드 목록
- 팩트 카드
- 관련 목적지 목록
- 완성률

## 11.4 모바일 고려

- 모바일은 좌측 리스트를 상단 탭 또는 슬라이드 리스트로 전환한다.
- 본문은 긴 스크롤 1열 구조로 단순화한다.
- `FactTier`는 접이식 카드로 처리한다.

## 11.5 읽기 UX 원칙

- 처음 보이는 텍스트는 짧아야 한다.
- 정보량이 늘수록 `탭`, `펼치기`, `카드`로 분리한다.
- 문단보다 짧은 팩트 카드가 우선이다.

## 12. 콘텐츠 톤 가이드

## 12.1 현실 기반 항목

- 사실 중심
- 짧고 명확한 문장
- 과장 금지
- 흥미 포인트는 별도 팩트 카드로 분리

## 12.2 SF/후반 우주 영역 항목

후반 일부 목적지는 현실 탐사보다 `세계관적 해석`이 강해질 수 있다. 이 경우 아래 문구 체계를 권장한다.

- `Confirmed Data`
- `Mission Estimate`
- `Deep Space Record`

즉, 현실 과학 정보와 게임적 해석을 같은 문체로 섞지 않는다.

## 13. 구현 가능성과 기술 설계

## 13.1 현재 코드 기준 구현 가능성 (Godot 4.6)

구현 가능성은 높다.

- `DestinationService.complete_destination(d_id)`가 도감 해금 훅으로 적합하다.
- `SaveSystem`의 `user://savegame.json` 스키마에 `discovery` 필드를 넣기 쉽다.
- `scenes/ui/global_hud.tscn`에 Codex 메뉴 버튼/패널 추가가 자연스럽다.
- `EventBus.destination_completed` 시그널은 결과 UI 전달 지점이라 도감 요약 필드를 함께 싣기 좋다.

## 13.2 권장 데이터 저장 방식

좋은 방향은 `파생 가능한 상태를 중복 저장하지 않는 것`이다.

권장 저장 예시 (`user://savegame.json` 내 `discovery` 필드):

```json
{
    "discovery": {
        "entries": {
            "BODY_MARS": {
                "viewed": true,
                "discovered_destination_ids": ["D_36", "D_39", "D_53"]
            }
        }
    }
}
```

이 구조의 장점:

- 어떤 목적지를 성공했는지만 저장하면 된다.
- 섹션 해금 여부, FactTier, 완성률은 `CodexConfig` 리소스 기준으로 계산 가능하다.
- 중복 상태 저장 버그를 줄일 수 있다.

## 13.3 권장 Config 구조 (Godot Resource)

신규 파일:

- `data/codex_config.tres` (`Resource` 상속)

권장 GDScript 클래스 구조:

```gdscript
class_name CodexConfig extends Resource

@export var entries: Array[CodexEntry] = []

class_name CodexEntry extends Resource

@export var id: String = ""                       # "BODY_MARS"
@export var display_name: String = ""             # "Mars"
@export var entry_type: String = "planet"         # planet / moon / system / region
@export var summary: String = ""                  # "붉은 행성. 고대 물의 흔적과 ..."
@export var icon: Texture2D
@export var destination_ids: Array[String] = []   # ["D_36", "D_37", ...]
@export var sections: Array[CodexSection] = []
@export var fact_thresholds: Array[int] = [1, 2, 4]
@export var completion_required_section_ids: Array[String] = []
@export var completion_minimum_distinct_destinations: int = 4

class_name CodexSection extends Resource

@export var id: String = ""                       # "surface"
@export var title: String = ""                    # "Surface"
@export var required_destination_ids: Array[String] = []
```

리소스 파일 (`.tres`)은 Godot 에디터의 Inspector에서 직접 편집 가능. 기획자가 직접 텍스트 / 목적지 매핑을 수정할 수 있다.

## 13.4 권장 서비스 (Godot Autoload 또는 노드)

신규 파일:

- `scripts/services/discovery_service.gd`

역할:

- `EventBus.destination_completed`에 연결하여 자동으로 `entry_id` 판별
- `discovered_destination_ids` 누적
- 신규 엔트리 / 신규 섹션 / 완성 여부 계산
- `EventBus.codex_updated` 시그널 발화
- `BadgeService` / `MissionService` / `TelemetryService` 구독자에 자연 전파

## 13.5 권장 EventBus 시그널

Godot 싱글 클라이언트이므로 네트워크 패킷은 불필요. `EventBus` 시그널만 정의.

```gdscript
# scripts/autoload/event_bus.gd
signal codex_entry_unlocked(entry_id: String)
signal codex_entry_updated(entry_id: String, newly_discovered_destination_ids: Array[String])
signal codex_section_unlocked(entry_id: String, section_id: String)
signal codex_entry_completed(entry_id: String)
```

UI는 이 시그널에 연결해서 NEW / UPDATED / COMPLETE 배지를 업데이트한다.

## 13.6 `destination_completed` 연동 방식

`DiscoveryService`는 `EventBus.destination_completed` 시그널을 구독하고, 해당 목적지와 연결된 엔트리를 순회하여 위 시그널들을 이어서 발화한다.

```gdscript
# scripts/services/discovery_service.gd
func _ready() -> void:
    EventBus.destination_completed.connect(_on_destination_completed)

func _on_destination_completed(destination_id: String, _reward: Dictionary) -> void:
    for entry in codex_config.entries:
        if destination_id in entry.destination_ids:
            _process_entry(entry, destination_id)
```

Win Screen 모달도 같은 시그널을 구독해 **NEW CODEX ENTRY** 카드를 자체적으로 렌더한다 (패킷 확장 불필요).

## 13.7 권장 UI 파일 구조 (Godot)

신규 후보 파일:

- `scenes/ui/codex_panel.tscn` + `scripts/ui/codex_panel.gd`
- `scenes/ui/codex_entry_panel.tscn` + `scripts/ui/codex_entry_panel.gd`

수정 후보 파일:

- `scenes/ui/global_hud.tscn` + `scripts/ui/global_hud.gd` — Codex 메뉴 버튼 / NEW 배지
- `scenes/ui/win_screen.tscn` + `scripts/ui/win_screen.gd` — 신규 도감 카드
- `scripts/autoload/event_bus.gd` — 신규 시그널 추가
- `scripts/autoload/save_system.gd` — `discovery` 필드 마이그레이션
- `scripts/services/destination_service.gd` — (변경 없음, 시그널만 발화)

## 14. 기대 효과와 부작용

## 14.1 기대 효과

- 발사 성공이 더 기억에 남는다.
- 같은 천체 계열 목적지를 다시 시도할 이유가 생긴다.
- 목적지 리스트가 단순 숫자 단계가 아니라 테마 맵으로 보이기 시작한다.
- 장기적으로 완성률, 컬렉션, 과제와 결합하기 쉽다.

## 14.2 나쁜 방향으로 갈 때의 부작용

- 진행도 요구치가 과하면 숙제처럼 느껴진다.
- 텍스트가 길면 아무도 읽지 않는다.
- 엔트리 수가 너무 많으면 도감이 또 다른 목적지 리스트가 된다.
- 팩트와 섹션 구조가 제각각이면 운영 비용이 커진다.

## 14.3 대응 원칙

- 모든 요구치는 `서로 다른 목적지 수` 기준으로 잡는다.
- 엔트리당 필수 섹션은 3개 전후로 제한한다.
- 텍스트는 `짧은 요약 + 카드형 팩트`를 우선한다.
- 출시 초기에는 12개 핵심 엔트리만 운영한다.

## 15. BM 및 라이브 운영 방향

## 15.1 좋은 방향

- 도감 기본 열람은 무료
- BM은 편의/표현 중심
- 미션은 도감 활용 가능

예시:

- `새 섹션 1개 해금`
- `도감 엔트리 3개 열람`
- `목성계 엔트리 2개 진행`

## 15.2 나쁜 방향

- 엔트리 열람권 자체 판매
- 상세 설명 유료 잠금
- 도감 완성으로 성공률/보상 배율 직접 상승

도감은 `브랜드 가치`와 `세계관 몰입`을 담당하는 축이므로, 핵심 접근을 유료화하면 손해가 더 크다.

## 16. 제작 우선순위

## 16.1 기획

- 12개 출시 엔트리 최종 확정
- `Destination -> CodexEntry -> Section` 매핑 표 작성
- 엔트리별 완성 조건 고정
- 텍스트 길이 기준 확정

## 16.2 엔지니어링 (Godot)

- `SaveSystem` 스키마에 `discovery` 필드 추가 + 마이그레이션 훅
- `data/codex_config.tres` 리소스 작성 (12 엔트리)
- `scripts/services/discovery_service.gd` Autoload 추가
- `EventBus`에 `codex_*` 시그널 4종 추가
- `scenes/ui/global_hud.tscn`, `scenes/ui/win_screen.tscn`, `scenes/ui/codex_panel.tscn` 연결

## 16.3 콘텐츠

- 엔트리명, 요약, 팩트 카드 작성
- 섹션 제목과 잠금 해제 문구 작성
- 현실 정보 검수
- SF형 항목 톤 분리

## 16.4 UI/아트

- 도감 리스트 아이템
- 엔트리 상세 패널
- `NEW / UPDATED / COMPLETE` 배지
- 엔트리 타입 아이콘

## 16.5 QA

- 신규 해금/기존 업데이트/완성 상태가 정확히 분리되는지 확인
- 같은 목적지 반복 성공 시 중복 카운트가 없는지 확인
- 모바일에서 긴 상세 패널 가독성 확인
- 승리 화면 흐름이 과도하게 늘어지지 않는지 확인

## 17. 운영 지표

출시 후 반드시 봐야 하는 지표:

- 첫 도감 해금 도달율
- 해금 직후 `View Codex` 클릭률
- 엔트리당 평균 발견 목적지 수
- 엔트리 완성률 분포
- 도감 기능 사용 유저의 재방문율 차이

특히 아래 현상이 나오면 방향 수정이 필요하다.

- 해금은 많지만 열람률이 매우 낮다
- 특정 엔트리 완성률만 비정상적으로 낮다
- 동일 목적지 반복 성공 비율이 높고, 도감 진행과 상관이 없다

## 18. 최종 요약

추천방향 B는 현재 게임 구조에서 충분히 구현 가능하며, 발사 루프에 `수집`, `탐사`, `완성`의 의미를 붙이는 가장 좋은 방향이다.

다만 성공하려면 아래 4가지를 지켜야 한다.

1. `목적지`와 `도감 엔트리`를 분리할 것
2. `같은 목적지 반복`이 아니라 `서로 다른 목적지 탐사`를 진행도로 볼 것
3. `장문 강제 열람`이 아니라 `짧은 요약 + 선택 열람`으로 설계할 것
4. 출시 초기에는 `12개 핵심 엔트리의 Lite B 구조`로 시작할 것

이 기준으로 진행하면, 도감은 단순 읽기 기능이 아니라 이 게임의 장기 메타 목표이자 우주 테마 차별화 장치로 기능할 수 있다.
