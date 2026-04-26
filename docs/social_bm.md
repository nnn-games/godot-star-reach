# 메타 보너스 / 리텐션 보상 기획안 (싱글 오프라인)

> **문서 유형**: 메타 보너스 / 리텐션 설계
> **작성일**: 2026-04-24
> **관련 문서**: `docs/bm.md` §10, `docs/launch_balance_design.md`

---

## 1. 문서 목적

싱글 오프라인 Mobile / Steam 게임에서 **일일 복귀와 장기 체류**를 만들기 위한 메타 보너스 메커니즘을 정리한다.

| 노리는 효과 | 메커니즘 |
|---|---|
| 신규 유저 온보딩 가속 | 일일 로그인 보너스 / Starter Pack |
| 매일 들어올 이유 | 일일 보상 스트릭 / 일일 미션 |
| 세션 길이 연장 | Auto Launch + Daily Mission "10분 플레이" 미션 |
| 장기 체류 동기 | 도감 / Region Mastery / 플레이타임 칭호 |
| 자발적 응원 행동 | Steam Wishlist + Google Play 별점 + 인앱 평점 모달 (시간 후) |

---

## 2. 설계 원칙

### 2.1 모든 메타 보너스는 "검증 가능한 행동"에만 보상한다

- 시간 / 진행도 / 누적 행동 등 **클라이언트가 명확히 측정할 수 있는 지표**에 연결
- 외부 API (Steam Friends, Google Play Games Friends) 의존을 만들지 않는다 (싱글 게임 정책)

### 2.2 하드 재화(Credit)는 일일 캡, 코스메틱은 일회성

- Credit / TechLevel 같은 영구 재화는 **일일 / 주간 캡** 적용 → 경제 곡선 보호
- 칭호 / 코스메틱은 **컬렉션 만족** 위주

### 2.3 IAP / 구독을 보호한다

- 메타 보너스가 강해지면 VIP / Auto Launch Pass / Subscription 구매 동기를 잠식
- 메타 보너스의 효과는 **"있으면 약간 빠르고 재미있다"** 수준 — 핵심 가속은 IAP가 담당

---

## 3. 메타 보너스 풀

### 3.1 일일 로그인 보너스 (Daily Reward)

`docs/bm.md` §9.1 참조. 7일 스트릭 + 일일 광고 2배 옵션.

### 3.2 일일 미션 (Daily Mission)

`docs/bm.md` §9.2 참조. 3개/일 (구독자 +1) + 일일 TechLevel 캡 50.

### 3.3 누적 플레이타임 칭호

| 누적 시간 | 칭호 | 보상 |
|---|---|---|
| 10시간 | `Cadet` | 100 Credit + 칭호 |
| 50시간 | `Engineer` | 500 Credit + 칭호 + 트레일 코스메틱 |
| 100시간 | `Mission Director` | 1,000 Credit + 칭호 + 트레일 코스메틱 |
| 500시간 | `Veteran Operator` | 5,000 Credit + 칭호 + 발사대 스킨 |
| 1000시간 | `Stellar Architect` | 10,000 Credit + 칭호 + 영구 트레일 코스메틱 |

데이터: `GameState.total_play_time_sec` (`_process(delta)`에서 누적, 1초 주기로 SaveSystem에 반영).

### 3.4 도감 진행도 보너스

| 도감 진척도 | 보상 |
|---|---|
| 25% | 칭호 `Stargazer` + 500 Credit |
| 50% | 칭호 `Astronomer` + 2,000 Credit + 트레일 코스메틱 |
| 75% | 칭호 `Cosmographer` + 5,000 Credit + 발사대 스킨 |
| 100% | 칭호 `Celestial Master` + 15,000 Credit + 영구 코스메틱 + 한정 마일스톤 영상 |

데이터: `DiscoveryService.completion_ratio()`.

### 3.5 Region Mastery

`docs/contents.md`의 11개 Zone 각각에 대해 모든 목적지 클리어 시:

| Region | 마스터리 칭호 | 보상 |
|---|---|---|
| Earth Region | `Atmospheric Pioneer` | 200 Credit + 트레일 |
| Lunar & NEO | `Lunar Explorer` | 500 Credit |
| Inner Solar System | `Mars Pathfinder` | 1,000 Credit |
| Asteroid Belt | `Belt Navigator` | 1,500 Credit |
| Jovian System | `Jovian Voyager` | 2,500 Credit |
| Saturnian System | `Ringmaster` | 3,500 Credit |
| Ice Giants | `Cryosphere Explorer` | 5,000 Credit |
| Pluto / Kuiper | `Outer Bound` | 7,500 Credit |
| Interstellar | `Interstellar Pilot` | 12,000 Credit |
| Milky Way Landmarks | `Galactic Cartographer` | 18,000 Credit + 발사대 스킨 |
| Deep Space | `Cosmic Frontier` | 30,000 Credit + 영구 코스메틱 + 엔딩 마일스톤 영상 |

### 3.6 첫도달 마일스톤

| 누적 첫도달 | 보상 |
|---|---|
| 10개 | 칭호 `Pathfinder` + 200 Credit |
| 25개 | 칭호 `Trailblazer` + 750 Credit + 트레일 코스메틱 + **마일스톤 영상 (D_25)** |
| 50개 | 칭호 `Voyager` + 2,000 Credit + 발사대 스킨 + **마일스톤 영상 (D_50)** |
| 75개 | 칭호 `Pioneer` + 5,000 Credit + 트레일 코스메틱 + **마일스톤 영상 (D_75)** |
| 100개 | 칭호 `Star Reacher` + 15,000 Credit + 영구 코스메틱 + **엔딩 마일스톤 영상 (D_100)** |

### 3.7 시즌 컬렉션 (분기별)

3개월 시즌마다 한정 코스메틱 컬렉션 (트레일 / 발사대 / 칭호) 제공. 시즌 종료 후 미수집은 영구 미획득.

| 시즌 | 테마 | 한정 보상 |
|---|---|---|
| S01 | Lunar Apollo 50주년 | 아폴로 패치 트레일 + 새턴 V 발사대 스킨 |
| S02 | Mars Mission Era | 화성 적색 트레일 + 큐리오시티 발사대 스킨 |
| S03 | Voyager Anniversary | 보이저 골든 레코드 트레일 + 보이저 발사대 스킨 |
| S04 | JWST Decade | 적외선 무지개 트레일 + JWST 발사대 스킨 |

---

## 4. 데이터 구조

```gdscript
# GameState
{
    "meta_bonus": {
        "title_owned": ["Cadet", "Stargazer"],            # 영구 획득 칭호
        "title_equipped": "Stargazer",                      # 표시 칭호
        "cosmetics_owned": ["trail_aurora", "pad_classic"], # 영구 획득 코스메틱
        "cosmetics_equipped": {
            "trail": "trail_aurora",
            "launchpad": "pad_classic"
        },
        "playtime_milestones_claimed": [10, 50],            # 시간 단위 (h)
        "codex_milestones_claimed": [25, 50],               # 진척도 (%)
        "region_mastery_claimed": ["EARTH_REGION"],
        "first_arrival_milestones_claimed": [10, 25],
        "season_collection": {
            "current_season_id": "S01",
            "items_collected": ["s01_apollo_trail"]
        }
    }
}
```

---

## 5. 노출 / UI 규칙

### 5.1 노출 시점

| 메커니즘 | 노출 시점 | UI |
|---|---|---|
| 일일 로그인 | 일자 변경 후 첫 진입 | 모달 자동 |
| 누적 플레이타임 도달 | 임계 통과 시 | 토스트 + 메뉴 배지 |
| 도감 진행도 도달 | 임계 통과 시 | 토스트 + Codex 메뉴 배지 |
| Region Mastery | Region 완료 시 | 화이트 페이드 + 칭호 부여 컷 |
| 첫도달 마일스톤 | 카운트 도달 시 | 마일스톤 영상 (해당 임계) |
| 시즌 컬렉션 진척 | 진척 변경 시 | 시즌 패널 배지 |

### 5.2 칭호 / 코스메틱 표시

- 칭호: 메인 화면 좌상단 닉네임(또는 "Mission Director") 옆에 작게
- 트레일 코스메틱: 발사 시 로켓 트레일 색/패턴
- 발사대 스킨: 메인 화면 발사대 스프라이트 교체

### 5.3 Steam / Google Play 평점 유도 (소셜 응원 대체)

| 트리거 | 모달 |
|---|---|
| 누적 50시간 + T3 클리어 | "게임을 즐기고 계신가요? 별점을 남겨주세요" 모달 (1회만) |
| 누적 100시간 + 도감 50% | (위 모달 미평가 시) 1회 추가 노출 |

플랫폼 API:
- iOS: `SKStoreReviewController.requestReview()` (연 3회 한도, OS가 자동 관리)
- Android: Google Play Core Library의 `ReviewManager`
- Steam: 모달에서 "Steam 리뷰 작성" 버튼 → `Steam.activateGameOverlayToWebPage()` 로 리뷰 페이지 이동

---

## 6. KPI 제안

리텐션 메커니즘이 작동하는지 보려면 아래를 본다.

1. **D1 / D7 / D30 리텐션** — 일일 보상 스트릭과 직접 연결
2. **세션당 평균 플레이타임** — Daily Mission "10분 플레이" 효과 측정
3. **도감 진행도 분포** — 메타 보너스의 장기 동기 부여 효과
4. **누적 100시간 도달율** — Veteran 칭호 도달율로 장기 코어 팬 비중 파악
5. **시즌 컬렉션 참여율** — FOMO 메커니즘 유효성

---

## 7. 최종 제안

싱글 오프라인에서 리텐션의 핵심은 다음 한 줄로 요약된다.

> **"매일 들어와야 하는 작은 보상 + 모으고 싶은 큰 컬렉션 + 가끔 인생샷처럼 펼쳐지는 마일스톤 영상 컷"**

세 축이 **일일 / 주간 / 누적** 시간축에 분산되어 있어, 한 축이 약해져도 다른 축이 유저를 잡아둔다. 이 게임은 멀티가 없기 때문에 **컬렉션 깊이와 시각적 임팩트의 분배**가 곧 리텐션이다.
