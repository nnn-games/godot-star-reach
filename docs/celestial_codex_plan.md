# 천체 도감 기능 기획 초안

> 작성일: 2026-04-24
> 목적: 목표 타깃(발사 목적지) 도달 성공 시 해당 천체에 대한 도감이 해금되고, 플레이어가 천체 상세 정보를 볼 수 있게 하는 기능의 기획 초안을 정리한다.
> 기준 구현 (Godot 4.6): `scripts/services/destination_service.gd`, `scripts/autoload/save_system.gd`, `scenes/ui/global_hud.tscn`, `scenes/ui/destination_panel.tscn`, `data/destination_config.tres`
> 관련 문서: `docs/destination_config.md`, `docs/rocket_launch_implementation_spec.md`, `docs/rocket_launch_content_preparation.md`

> 결정: 본 문서의 `추천 방향 B: 천체 중심 + 탐사 진행도`를 확정안으로 채택한다.
> 상세 실행 기획안: `docs/celestial_codex_design_plan.md`

## 1. 기능 목표

이 기능의 목적은 단순히 "목적지를 하나 더 클리어했다"에서 끝나지 않고, 그 성공이 플레이어의 지식 수집과 세계관 확장으로 이어지게 만드는 것이다.

핵심 목표는 4가지다.

1. 발사 성공의 보상을 숫자 보상 외에 수집 보상으로 확장한다.
2. 각 목적지와 천체에 의미를 부여해 반복 발사 동기를 강화한다.
3. 이 게임의 차별점인 우주/천체 테마를 교육적이면서도 게임적으로 활용한다.
4. 장기적으로는 도감 완성, 천체군 컬렉션, 미션 연계까지 확장 가능한 구조를 만든다.

## 2. 현재 구현 기준으로 본 구현 가능성

## 2.1 결론

구현 가능성은 높다.

이유는 다음과 같다.

- 목적지 클리어 시점이 `DestinationService.complete_destination()`로 명확하게 집중되어 있다.
- 플레이어 영구 데이터가 `SaveSystem`의 `user://savegame.json` 구조로 이미 운영되고 있다.
- `GlobalHUD`에 오버레이 패널을 추가하는 패턴이 이미 있다.
- 목적지 데이터가 `data/destination_config.tres`로 중앙화되어 있어, 도감 메타데이터를 연결하기 쉽다.
- 승리 직후 `WinScreen`을 띄우는 흐름이 이미 있어 "신규 도감 해금" 피드백을 넣기 좋다.

즉, "언제 해금할지", "어디에 저장할지", "어디서 보여줄지" 3가지 축이 모두 이미 존재한다.

## 2.2 구현 난이도

| 영역 | 난이도 | 이유 |
|---|---|---|
| 데이터 저장 | 낮음 | `SaveSystem` JSON에 `discovery` 필드 추가로 해결 |
| 해금 판정 | 낮음 | 목적지 완료 시그널이 이미 발화 중 |
| 시그널 연결 | 낮음 | `EventBus` 시그널 4종 추가만 필요 |
| 기본 UI 패널 | 중간 | GlobalHUD overlay 패턴 재사용 가능 |
| 콘텐츠 데이터 설계 | 중간 | 천체/목적지 분리 모델 설계가 필요 |
| 실제 텍스트/이미지 생산 | 중간~높음 | 기능보다 콘텐츠 제작량이 더 큼 |
| 미션 확장 | 중간 | 핵심 기능 뒤에 붙이는 것은 쉬우나, 잘못 붙이면 UX 훼손 가능 |

## 3. 가장 중요한 구조 결정

## 3.1 권장안: `Destination`와 `도감 엔트리`를 분리한다

현재 게임의 `Destination`은 100개 이상으로 확장 가능한 발사 목표다. 하지만 도감의 단위까지 `Destination`와 1:1로 맞추는 것은 비효율적이다.

예를 들어 아래 목적지들은 서로 다른 `Destination`이지만 같은 천체군을 공유한다.

- 여러 개의 달 관련 목적지
- 여러 개의 화성 관련 목적지
- 여러 개의 목성/토성 위성 관련 목적지

따라서 아래 구조를 권장한다.

- `Destination`: 게임 플레이용 발사 목표
- `CodexEntry`: 천체/우주 지식용 도감 항목

즉, 하나의 `CodexEntry`에 여러 `Destination`이 연결될 수 있어야 한다.

## 3.2 권장 매핑 예시

| Destination 예시 | 연결 CodexEntry 예시 |
|---|---|
| `Lunar Flyby`, `Lunar Orbit`, `South Pole Landing` | `BODY_MOON` |
| `Mars Flyby`, `Jezero Crater`, `Phobos Landing` | `BODY_MARS` + 세부 섹션 |
| `Europa`, `Ganymede`, `Great Red Spot` | `BODY_JUPITER_SYSTEM` 또는 세부 개별 항목 |

## 3.3 왜 1:1이 안 좋은가

`Destination = 도감 엔트리`로 가면 다음 문제가 생긴다.

- 텍스트가 100개 이상으로 급증한다.
- 같은 천체 정보가 여러 목적지에서 중복된다.
- 플레이어가 "같은 달인데 왜 도감이 5개냐"는 혼란을 느낀다.
- 운영/로컬라이징 비용이 급격히 늘어난다.

## 4. 추천 기능 방향

## 4.1 추천 방향 A: 천체 중심 도감

가장 추천하는 기본 형태다.

- 플레이어가 특정 목적지를 처음 성공하면 해당 천체 엔트리가 해금된다.
- 도감은 "천체" 중심으로 묶인다.
- 엔트리 안에서 관련 발사 목적지 목록을 함께 보여준다.

예시:

- 달 첫 관련 목적지 클리어 -> `Moon Codex` 해금
- 이후 달 관련 다른 목적지 클리어 -> 같은 엔트리 안의 하위 섹션 또는 탐사 기록이 추가

장점:

- 콘텐츠 중복이 적다.
- 플레이어가 이해하기 쉽다.
- 우주 교육 콘텐츠와 잘 맞는다.
- 초기 버전 제작 비용이 상대적으로 낮다.

## 4.2 추천 방향 B: 천체 중심 + 탐사 진행도

A안의 확장판이다.

- 엔트리 자체는 천체 단위로 묶는다.
- 하지만 같은 천체의 하위 탐사 성과를 누적한다.

예시:

- `Mars` 엔트리
  - 개요 해금: 화성 첫 도달
  - 표면 섹션 해금: Jezero / Olympus Mons 계열 성공
  - 위성 섹션 해금: Phobos / Deimos 계열 성공
  - 심화 팩트 해금: 화성 관련 목적지 5개 성공

장점:

- 발사 반복의 의미가 생긴다.
- 같은 천체를 여러 번 가는 이유가 생긴다.
- 수집률, 완성률, 장기 리텐션 설계가 쉽다.

단점:

- 초기 데이터 설계가 조금 더 복잡하다.
- UI 구조를 탭/섹션 방식으로 잡아야 한다.

## 4.3 비추천 방향: 목적지 1개당 도감 1개

이 방향은 구현 자체는 쉽지만 장기적으로 좋지 않다.

문제:

- 100개 목적지면 도감도 100개가 된다.
- 같은 계열 천체가 지나치게 잘게 쪼개진다.
- 읽는 재미보다 리스트 과부하가 커진다.
- 텍스트 작성량과 검수 비용이 폭증한다.

이 방향은 "교육용 데이터베이스"에는 맞을 수 있지만, 모바일 / Steam 게임 UX에는 무겁다.

## 5. 기능 구조 초안

## 5.1 플레이어 경험 흐름

1. 플레이어가 목적지 클리어
2. 서버가 해당 목적지와 연결된 `CodexEntry`를 확인
3. 신규 해금이면 프로필에 해금 저장
4. 승리 화면 또는 직후 팝업에서 `NEW CODEX ENTRY` 노출
5. 플레이어는 `View Codex` 버튼으로 즉시 열람 가능
6. 이후 `GlobalHUD`의 `CODEX` 버튼에서 언제든 재열람 가능

## 5.2 권장 UI 흐름

### 진입점

- `WinScreen` 내 `New Codex Entry` 카드/버튼
- `GlobalHUD`의 신규 버튼 `CDX` 또는 `CODEX`
- 목적지 선택 패널에서 관련 도감 미리보기 버튼

### 도감 화면 구성

권장 UI는 2단 구조다.

1. 왼쪽 또는 상단: 도감 엔트리 리스트
2. 오른쪽 또는 본문: 선택 엔트리 상세

상세 화면 권장 정보:

- 천체 이름
- 분류
- 대표 이미지 또는 아이콘
- 2~3줄 요약
- 상세 설명
- 흥미 사실 3개 내외
- 관련 목적지 목록
- 현재 탐사 진척도

## 5.3 상세 페이지 탭 예시

| 탭 | 내용 |
|---|---|
| `Overview` | 천체 기본 설명 |
| `Facts` | 흥미 사실 / 수치 |
| `Exploration` | 관련 목적지 / 플레이어 달성 현황 |
| `Gallery` | 이미지나 기념 일러스트, 추후 확장 |

초기 버전에서는 `Overview + Facts`만으로도 충분하다.

## 6. 구현 관점에서 좋은 방향

## 6.1 좋은 방향 1: `CodexConfig`를 별도 파일로 분리

권장:

- `DestinationConfig`는 플레이용 밸런스 데이터로 유지
- 도감 데이터는 `CodexConfig` 또는 `CelestialCodexConfig`로 분리

이유:

- 게임 밸런스 데이터와 지식 콘텐츠 데이터의 변경 주기가 다르다.
- 도감은 다국어/이미지/설명 확장이 들어가므로 파일 구조를 분리하는 편이 안전하다.

권장 예시 (Godot Resource):

```gdscript
# data/codex_config.tres
class_name CodexConfig extends Resource
@export var entries: Array[CodexEntry] = []

# data/codex_entries/body_moon.tres
class_name CodexEntry extends Resource
@export var id: String = "BODY_MOON"
@export var display_name: String = "Moon"
@export var category: String = "Natural Satellite"
@export var tier: int = 2
@export var summary: String = "..."
@export var facts: Array[String] = []
@export var related_destination_ids: Array[String] = []
@export var icon: Texture2D
```

## 6.2 좋은 방향 2: 해금 판정은 서비스, 텍스트 렌더는 UI

권장 구조:

- `DiscoveryService`는 "이 엔트리가 해금되었는가"만 판단해서 시그널 발화
- `CodexPanel`은 로컬 `data/codex_config.tres`를 바탕으로 내용을 렌더

장점:

- 모듈 결합도가 낮다.
- 콘텐츠 조회가 빠르다 (Resource는 메모리 캐시됨).
- 시그널 페이로드는 entry_id만 전달, 본문 텍스트는 전달하지 않음.

## 6.3 좋은 방향 3: 해금과 열람을 분리

권장 UX:

- 성공 즉시 자동으로 긴 텍스트를 강제 노출하지 않는다.
- 대신 "해금 알림"만 보여주고, 읽기는 선택하게 한다.

이유:

- 플레이 리듬을 해치지 않는다.
- 모바일 / Idle 게임 유저는 텍스트 강제 노출을 매우 싫어한다.

## 6.4 좋은 방향 4: 도감 완성률을 장기 목표로 사용

도감의 장점은 단순 1회 팝업이 아니라 장기 축적 목표를 만들 수 있다는 점이다.

예시:

- 전체 도감 완성률
- 티어별 완성률
- 달/화성/외태양계 세트 완성 보상
- "첫 열람"과 "첫 완성"을 분리한 배지 설계

## 6.5 좋은 방향 5: 교육 콘텐츠는 짧고 계층적으로

모바일 / Idle UX에서는 긴 백과사전식 본문보다 아래 구조가 낫다.

- 첫 화면: 2~3줄 요약
- 펼치기/탭: 상세 설명
- `Did you know?` 형식의 짧은 팩트 카드

즉, 처음부터 장문을 넣기보다 "짧은 핵심 -> 원하면 자세히" 구조가 좋다.

## 7. 안 좋은 방향

## 7.1 안 좋은 방향 1: 도감 열람을 진행 필수로 만드는 것

예:

- 도감을 읽어야 다음 목적지 해금
- 도감 열람 버튼을 눌러야 보상 수령
- 도감 페이지를 끝까지 스크롤해야 완료 처리

이 방식은 리듬을 깨고, "배우는 재미"가 아니라 "숙제"처럼 느껴지게 한다.

## 7.2 안 좋은 방향 2: 도감에 수치 보너스를 직접 붙이는 것

예:

- 도감 10개 읽으면 성공률 +5%
- 도감 완독 시 XP 배율 증가

이런 구조는 읽고 싶은 사람을 위한 기능이 아니라 성능용 클릭 요소가 된다. 도감의 의미가 훼손된다.

권장:

- 보상은 cosmetic, badge, collection prestige 쪽으로 붙인다.
- 핵심 전투/발사 밸런스에는 직접 연결하지 않는다.

## 7.3 안 좋은 방향 3: 기본 접근을 유료화하는 것

도감은 이 게임의 세계관 가치와 차별점이 될 수 있으므로 기본 열람 자체를 유료로 막는 것은 좋지 않다.

비추천:

- 기본 도감 열람권을 패스로 판매
- 상세 설명을 유료 잠금
- 신규 해금 알림을 유료 사용자만 받게 함

가능한 예외:

- 북마크/정렬/테마 같은 편의성
- 확장 갤러리 스킨

그래도 core access는 무료 유지가 좋다.

## 7.4 안 좋은 방향 4: 이미지/텍스트를 목적지마다 전부 개별 제작하는 것

100개 목적지 각각에:

- 전용 아트
- 전용 장문 설명
- 전용 UI 레이아웃

를 요구하면 제작비가 급증한다. 초기에는 절대 비추천이다.

## 7.5 안 좋은 방향 5: 현실 천문 정보와 게임 판타지를 구분하지 않는 것

현재 목적지에는 현실 기반 천체와 SF형 목적지가 섞여 있다. 도감에서 이 둘을 같은 톤으로 다루면 정보 신뢰감이 떨어질 수 있다.

권장:

- 현실 기반 항목: 사실 정보 중심
- SF/후반 목적지: "세계관 기록" 또는 "추정 데이터" 톤으로 분리

## 8. 시스템 설계 초안

## 8.1 데이터 모델 권장안

`SaveSystem` JSON에 아래 필드 추가를 권장한다.

```json
{
    "discovery": {
        "unlocked_entries": ["BODY_MOON", "BODY_MARS"],
        "viewed_entries": ["BODY_MOON"],
        "entry_progress": {
            "BODY_MARS": {
                "related_destination_ids": ["D_36", "D_39"]
            }
        }
    }
}
```

최소 버전은 `unlocked_entries`만 있어도 된다.

## 8.2 서비스 권장안 (Godot Autoload)

새 서비스 추가를 권장한다.

- `scripts/services/discovery_service.gd` (Autoload)

역할:

- 목적지 완료 시그널 구독 → 연결된 도감 엔트리 해금
- 플레이어 도감 상태 조회 API
- 열람 처리 (`mark_viewed(entry_id)`)
- `EventBus` 시그널 발화 → 배지/미션/텔레메트리 자연 전파

## 8.3 Config 권장안 (Godot Resource)

- `data/codex_config.tres` (`Resource` 상속, `class_name CodexConfig`)

이 파일에는 아래가 들어간다.

- 엔트리 정의 (`Array[CodexEntry]`)
- 엔트리와 목적지 연결 (`destination_ids`)
- 분류 (`entry_type`: planet / moon / system / region)
- 요약/상세 텍스트 (다국어 키)
- 아이콘 (`Texture2D`)
- 관련 팩트 (`facts: Array[String]`)

## 8.4 시그널 권장안 (네트워크 패킷 대체)

Godot 싱글이므로 패킷 대신 `EventBus` 시그널.

```gdscript
# scripts/autoload/event_bus.gd
signal codex_entry_unlocked(entry_id: String)
signal codex_entry_updated(entry_id: String)
signal codex_section_unlocked(entry_id: String, section_id: String)
signal codex_entry_completed(entry_id: String)
```

## 8.5 UI 권장안 (Godot Control)

추가 후보 파일:

- `scenes/ui/codex_panel.tscn` + `scripts/ui/codex_panel.gd`
- `scenes/ui/codex_entry_panel.tscn` + `scripts/ui/codex_entry_panel.gd`

연결 후보:

- `scenes/ui/global_hud.tscn` 메뉴 버튼 추가
- `scenes/ui/win_screen.tscn`의 신규 도감 해금 카드 추가

## 9. 기존 시스템과의 연결 방식

## 9.1 목적지 완료 지점

가장 자연스러운 연결 지점은 `DestinationService.complete_destination()` → `EventBus.destination_completed` 시그널이다.

이 지점의 장점:

- 목적지 클리어가 이미 확정된 이후다.
- 보상 지급, 총 승리 수 증가, 다음 목적지 이동 같은 영구 진행이 여기서 처리된다.
- 도감 해금을 "진짜 도달 성공"과 정확히 동기화할 수 있다.

## 9.2 승리 화면 연결

`EventBus.destination_completed`는 다음 페이로드를 전달한다.

- 목적지 ID
- reward (Credit, TechLevel)
- tier
- next_destination_id

`CodexPanel` / `WinScreen`은 이 시그널과 `EventBus.codex_entry_unlocked` / `codex_entry_updated`를 구독해 자체적으로 NEW 카드를 렌더한다 (별도 페이로드 확장 불필요).

## 9.3 HUD 오버레이 연결

`scenes/ui/global_hud.tscn`은 이미 아래 오버레이 패널 진입점을 갖고 있다.

- best_records (구 leaderboard)
- shop / iap
- badge
- mission
- destination
- facility_upgrade

따라서 `codex` 메뉴 버튼을 추가하는 것은 자연스럽다.

## 10. 기능 효과 분석

## 10.1 기대 효과

### 1. 발사 성공의 감정적 보상이 강해진다

지금은 성공 보상이 주로 다음과 같다.

- Credit
- Program Lv.
- 다음 목적지

여기에 "새 천체를 알게 됐다"는 수집 보상이 붙으면 성공 경험이 더 기억에 남는다.

### 2. 목적지의 의미가 선명해진다

현재는 목적지 이름이 많아질수록 플레이어가 그것을 단순 숫자 단계로만 받아들일 수 있다.

도감이 붙으면:

- 목적지가 왜 존재하는지
- 이 천체가 무엇인지
- 이전 목적지와 무엇이 다른지

가 더 분명해진다.

### 3. 우주 테마의 차별점이 강화된다

발사 게임은 숫자 루프만으로도 돌아가지만, 도감은 "이 게임만의 우주 콘텐츠 축"을 만들어 준다.

### 4. 장기 리텐션에 좋다

도감 완성률, 세트 완성, 신규 해금 알림은 반복 접속 동기를 만들기 좋다.

## 10.2 부작용 가능성

### 1. 텍스트 과잉

문장이 길고 항목이 많아지면 읽지 않는 기능이 될 수 있다.

### 2. 콘텐츠 제작 비용 증가

기능 자체보다 텍스트, 이미지, 검수, 로컬라이징 비용이 커질 수 있다.

### 3. 발사 루프의 속도 저하

성공할 때마다 긴 팝업이 강제로 나오면 반복 플레이 속도가 떨어진다.

### 4. 현실 정보 정확도 관리 부담

천체 정보를 "상세 정보"로 제공할 경우, 검수 품질이 낮으면 오히려 제품 가치가 떨어진다.

## 11. 추천 출시 범위

## 11.1 1차 출시 권장 범위

가장 현실적인 초기 범위는 아래다.

- 도감 엔트리 수: 12~20개
- 기준: 천체군 중심
- 텍스트: 요약 + 팩트 3개
- 이미지: 기본 아이콘/간단 대표 이미지
- 기능: 해금, 리스트, 상세 열람, 신규 해금 배지

즉, 처음부터 100개 목적지 전체를 문서형 도감으로 만드는 것이 아니라 "주요 천체군 도감"부터 시작하는 편이 좋다.

## 11.2 2차 확장

- 관련 목적지 기반 탐사 진척도
- 갤러리/기념 이미지
- 도감 완성률 보상
- 미션 연동

## 11.3 3차 확장

- 발사장 기념비 / 박물관 연동
- 친구와 비교 가능한 도감 완성률
- 티어별 세트 컬렉션

## 12. BM 관점 판단

## 12.1 좋은 BM 방향

도감은 기본 접근을 무료로 두고, 아래처럼 "비핵심 편의/표현"을 BM에 붙이는 정도가 안전하다.

- 도감 북마크 슬롯
- 커스텀 테마 스킨
- 확장 갤러리 프레임
- "Mission Control"류의 비교/검색 편의

## 12.2 나쁜 BM 방향

- 천체 설명을 유료 잠금
- 신규 도감 해금을 유료로 단축
- 도감 완성에 직접적인 파워 보너스 부여

이런 방식은 UX와 브랜드 가치 모두를 해칠 가능성이 높다.

## 13. 실제 구현 시 예상 수정 파일

### 신규 추가 가능성이 높은 파일

- `data/codex_config.tres` (Godot Resource)
- `data/codex_entries/*.tres` (엔트리별)
- `scripts/services/discovery_service.gd` (Autoload)
- `scenes/ui/codex_panel.tscn` + `scripts/ui/codex_panel.gd`
- `scenes/ui/codex_entry_panel.tscn` + `scripts/ui/codex_entry_panel.gd`

### 수정 가능성이 높은 기존 파일

- `scripts/autoload/save_system.gd` (`discovery` 필드 마이그레이션)
- `scripts/services/destination_service.gd` (시그널 발화만, 변경 없음)
- `scripts/autoload/event_bus.gd` (`codex_*` 시그널 4종 추가)
- `scenes/ui/global_hud.tscn` + `scripts/ui/global_hud.gd` (Codex 메뉴 버튼 + NEW 배지)
- `scenes/ui/win_screen.tscn` + `scripts/ui/win_screen.gd` (신규 도감 카드)

## 14. 권장 초안 요약

이 기능은 현재 구조에서 충분히 구현 가능하며, 특히 "발사 성공에 의미를 부여하는 수집형 메타 콘텐츠"로서 가치가 크다.

다만 방향을 잘못 잡으면 아래 문제가 생긴다.

- 텍스트 과잉
- 데이터 중복
- 제작비 증가
- 발사 루프 템포 저하

따라서 가장 추천하는 방향은 아래다.

1. `Destination`와 `CodexEntry`를 분리한다.
2. 도감은 "천체 중심"으로 설계한다.
3. 해금은 목적지 성공 시 서버에서 처리한다.
4. 승리 화면에는 "신규 해금 알림"만 주고, 읽기는 선택하게 한다.
5. 초기에는 12~20개 핵심 엔트리로 시작한다.
6. 장기적으로는 관련 목적지 기반 탐사 진척도 시스템으로 확장한다.

## 15. 바로 다음 단계 제안

이 초안 다음으로 가장 자연스러운 작업 순서는 아래다.

1. 도감 단위를 `천체`로 할지 `목적지`로 할지 최종 확정
2. 초기 엔트리 12~20개의 목록 작성
3. `Destination -> CodexEntry` 매핑 테이블 설계
4. `PlayerDataService` 저장 스키마 초안 확정
5. `WinScreen`과 `GlobalHUD`의 도감 진입 UX 목업 작성
