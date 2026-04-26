# 🚀 Star Reach 게임 컨셉

> **문서 유형**: 게임 컨셉 (Concept Document)
> **작성일**: 2026-04-24
> **대상 플랫폼**: Android (Google Play) / iOS (App Store) / PC Steam
> **장르**: 시뮬레이터 / 업그레이드 / 점진적 진행 (Incremental Simulator)
> **엔진**: Godot 4.6
> **상태**: 컨셉 정본
> **상세 문서**: `docs/prd.md`, `docs/design/game_overview.md`, `docs/contents.md`

---

## 1. 게임 개요 (Game Overview)

### 1.1 핵심 컨셉
플레이어는 작은 우주 스타트업의 운영자로서, 낮은 성공률에서 시작하여 기술을 반복적으로 업그레이드하면서 로켓 발사 성공률을 높이고, 궁극적으로 100개 이상의 실제 천체에 도달하는 것을 목표로 한다.

### 1.2 태그라인
> "실패에서 배우고, 기술로 극복하고, 별에 닿아라."

### 1.3 게임 유형 분류
| 분류 항목 | 내용 |
|---|---|
| 장르 | 점진적 진행(Incremental) + 클리커 시뮬레이터 |
| 플레이 스타일 | 반복 도전 / 업그레이드 루프 / 오프라인 자동 진행 |
| 세션 길이 | 단기 세션(5~15분) + 장기 복귀형(데일리 체크인) + 오프라인 진행 (캡 8h) |
| 플레이 모드 | **싱글 오프라인** |

---

## 2. 핵심 게임플레이 루프 (Core Loop)

### 2.1 기본 루프
```
[메인 화면 → LAUNCH 탭]
    → 각 단계별 성공/실패 판정 (사전 정의된 확률 규칙)
    → 연속 성공 시 목적지 도달
    → 경험치(XP) 획득 (성공/실패 모두)
    → XP로 Launch Tech 업그레이드 (세션형)
    → 목적지 완료 시 Credit + TechLevel 보상
    → Credit으로 Facility Upgrade (영구 성장)
    → 더 먼 목적지(다음 Tier)로 도전
    → [반복]
```

### 2.2 단계별 판정 시스템
- 각 발사는 **N개의 단계**로 구성 (예: 연료 점화 → 1단 분리 → 2단 점화 → 궤도 진입)
- 각 단계는 **독립적으로 확률 판정**
- **구간형 성공률 구조**를 사용 (정복한 구간은 자동으로 최고 확률 적용)
- 실패 시: 해당 단계 직전까지의 부분 XP 보존 + 다음 발사까지 약 0.8초

| 구간 | 스테이지 범위 | 기본 성공률 | 재도전 최고 성공률 |
|---|---|---|---|
| T1 | 1~4 | 50% | 85% |
| T2 | 5~6 | 44% | 78% |
| T3 | 7~8 | 36% | 72% |
| T4 | 9 | 28% | 66% |
| T5 | 10 | 22% | 60% |

> 상세 계산식과 저장 구조는 `docs/launch_balance_design.md` 기준.

---

## 3. 목적지 진행 시스템 (Progression Destinations)

### 3.1 11 Zone × 100 목적지

`docs/contents.md`에 정의된 100개 목적지를 11 Zone에 분포:

| Zone | 대표 목적지 | Tier 분포 |
|---|---|---|
| 1. Earth Region | 카르만 선 / ISS / Hubble | T1 |
| 2. Lunar & NEO | 고요의 바다 / JWST | T2 |
| 3. Inner Solar | 화성 올림푸스 산 / 금성 / 수성 | T3 |
| 4. Asteroid Belt | 베스타 / 세레스 | T3 |
| 5. Jovian System | 목성 대적점 / 유로파 | T4 |
| 6. Saturnian System | 토성 고리 / 타이탄 / 엔셀라두스 | T4 |
| 7. Ice Giants | 천왕성 / 해왕성 / 트리톤 | T4 |
| 8. Pluto / Kuiper | 명왕성 / 에리스 / 오르트 구름 | T5 |
| 9. Interstellar | 프록시마 b / 시리우스 / TRAPPIST-1 | T5 |
| 10. Milky Way | 오리온 성운 / 베텔게우스 / 게 성운 | T5 |
| 11. Deep Space | 안드로메다 / 궁수자리 A* / 사건의 지평선 | T5 |

### 3.2 목적지 도달 연출

| 연출 | 트리거 | 형식 |
|---|---|---|
| 일반 도달 | 모든 목적지 | Sky Transition (`ParallaxBackground` + `CanvasModulate` Tween 1.5~3초) |
| Zone 첫 진입 | Zone 첫 도달 | 사전 렌더 영상 (`VideoStreamPlayer`, 5~12초, 11종) |
| 마일스톤 | 누적 10/25/50/75/100 첫도달 | 사전 렌더 영상 + 칭호 + 대량 Credit |
| Region Mastery | 같은 지역 모든 목적지 클리어 | 칭호 + 코스메틱 + Credit |

---

## 4. 업그레이드 시스템 (Technology Tree)

### 4.1 Launch Tech (세션형, 5종, XP 소비)

목적지 변경 시 리셋. 짧은 피드백 루프.

| 카테고리 | 효과 |
|---|---|
| 🔥 Engine Precision | 단계 성공률 +2%/Lv (max +40%p) |
| 📡 Telemetry | XP 획득 +1/Lv |
| 🧪 Fuel Optimization | XP 배율 +5%/Lv (max 1.5x) |
| ⏱️ Auto-Checklist | 발사 준비 단축 -5%/Lv (max -50%) |
| 🛡️ Stress Bypass | Stress 누적 감소 +3%/Lv |

### 4.2 Facility Upgrades (영구형, 5종, Credit 소비)

장기 목표, 인플레이션 없는 1.2x 곡선.

| 카테고리 | 효과 |
|---|---|
| 🚀 Engine Tech | 기반 성공률 +1%/Lv (max +10%p) |
| 📊 Data Collection | XP 획득 +10%/Lv |
| 💰 Mission Reward | Credit 획득 +5%/Lv (max +100%) |
| ⭐ Tech Reputation | TechLevel 획득 +5%/Lv (max +50%) |
| 🤖 AI Navigation | 전체 성공률 보너스 +2%/Lv |

### 4.3 비용 구조
- 세션형: `costBase × (costGrowth ^ level)` 지수 증가 (예: `5 × 1.4^lv`)
- 영구형: `8 × 1.20^(level-1)` Credit (인플레이션 없음)

---

## 5. 경험치 및 보상 구조 (XP & Reward)

### 5.1 XP 획득 조건

| 상황 | XP 지급 |
|---|---|
| 단계 1개 성공 | 10 XP (+ Telemetry 보너스) |
| 전체 발사 성공 (목적지 완료) | 100 XP + 목적지 Credit + TechLevel |
| 발사 실패 (1단계도 성공 없음) | 5 XP (노력 보상) |
| 연속 실패 보정(N회 실패 후) | +XP 보너스 (Pity System) |
| 일일 첫 성공 | 2배 XP (Daily 보상) |

### 5.2 Pity System (연민 보정)
- X회 연속 전체 실패 시 다음 발사 단계 성공률 임시 보정
- UI에 노출하지 않음 (자동 동작)
- 무한 좌절 구간 방지

---

## 6. 시장 분석

### 6.1 모바일 (iOS + Android)

| 게임 | 누적 다운로드 | 시사점 |
|---|---|---|
| Spaceflight Simulator | 약 39,000,000+ (Google Play) | 모바일 로켓 시뮬레이터의 대표작 — 장르 수요 실증 |
| Egg, Inc. | 10,000,000+ / iOS 단독 월 $30만 | 로켓 발사가 핵심 루프인 Idle, 9년차 안정 매출 |
| Cell to Singularity | 1,000만+ | 교육적 Idle (진화론) — 우리 STEM 사촌격 |

### 6.2 Steam (PC)

| 게임 | 판매량 | 시사점 |
|---|---|---|
| Kerbal Space Program | 약 4,000,000장 ($40) | 우주 게임 장르 정의작 — PC 게이머 우주 지불 의향 검증 |
| Dyson Sphere Program | 약 1,700,000+장 ($20) | 5인 인디팀의 1.7M 판매 — 인디 가능성 |
| Mars Horizon | 200,000~500,000장 ($20) | ESA 협력 우주 시뮬 — 우리 컨셉과 가장 유사 |
| Melvor Idle | 500,000~1,000,000장 ($10) | MTX 0%로 누적 매출 $670만 — P2W 0% 검증 |

상세 시장 분석은 `docs/design/game_overview.md` §4 참조.

---

## 7. 타겟 유저

| 세그먼트 | 연령대 | 매력 포인트 |
|---|---|---|
| 성인 우주 팬덤 | 18~45세 | KSP / DSP / Mars Horizon 사용자 — 우주 진정성 + 캐주얼 접근성 |
| 모바일 Idle 마니아 | 25~45세 | Egg Inc / Melvor Idle 사용자 — 짧은 세션 / 오프라인 진행 |
| STEM 관심 학생 | 10~17세 | 실제 우주과학 + 학부모 승인 (아동 보호 가드) |
| 컬렉터형 | 13~25세 | 100 도감 + 19 뱃지 + 11 Region Mastery 수집 |

---

## 8. 차별화 포인트

| # | USP | 설명 |
|---|---|---|
| 1 | 단계별 확률 × 구간형 상한 | 단일 확률이 아닌 N단계 × 구간별 상한. 숙련도가 자동으로 편의성으로 전환 |
| 2 | 100+ 목적지 × 실제 천체 데이터 | KSP·Mars Horizon 수준 우주 진정성 + 캐주얼 접근성 |
| 3 | Stress / Abort 리스크 레이어 | 캐주얼 클리커에 전략 레이어 |
| 4 | Godot 단일 코드베이스 | 인디 규모로 Mobile + Steam 동시 출시 |
| 5 | P2W 0% | Melvor Idle ($670만 매출) 검증 모델 |

---

## 9. 핵심 리스크 및 완화

| 리스크 | 완화 |
|---|---|
| 초반 이탈 (성공률 낮음) | T1 baseChance 50% + 첫 2~3발 100% 보정 + Pity System |
| 단조로움 (반복 클릭) | Tier별 연출 변화 + Sky Transition + 도감 / 뱃지 / 마일스톤 영상 |
| 시각 품질 경쟁 | 2D 배경 레이어 + 파티클 + 사전 렌더 핵심 영상 조합 |
| Steam 환불 (첫 2시간) | 첫 2시간 내 T1 첫 클리어 보장 튜토리얼 |
| 모바일 첫 3일 70% 이탈 | Daily Reward 7일 스트릭 + Daily Mission + 오프라인 진행 |

---

## 10. 수익 모델 (요약)

상세는 `docs/bm.md` 참조.

### 10.1 Mobile (Android / iOS)
- F2P + 영구/소모 IAP ($0.99~$29.99)
- Subscription Orbital Operations Pass ($4.99/월)
- Rewarded Ad (Abort / Win / Daily / Auto-Fuel)
- Battle Pass (시즌 3개월, $9.99 Premium)

### 10.2 Steam (PC)
- Standard Edition $14.99 / Deluxe $24.99
- Expansion DLC (분기, $7.99) — Interstellar Frontier 등
- Cosmetic DLC ($2.99~$4.99)
- 광고 / 가챠 / 확률형 상품 없음 (PC 게이머 문화 대응)

---

## 11. 기술 스택 (요약)

| 영역 | 선택 |
|---|---|
| 엔진 | **Godot 4.6** (GDScript) |
| 렌더러 | GL Compatibility (모바일) / Direct3D 12 (Windows) |
| 아키텍처 | Godot **Autoload 싱글톤** + 서비스 노드 |
| 이벤트 | Godot Signal + `EventBus` 오토로드 |
| 데이터 영속 | 로컬 `user://savegame.json` (JSON, 스키마 버전 + 마이그레이션) |
| 데이터 정의 | `Resource` (`.tres`) — `LaunchBalanceConfig`, `SkyProfile` 등 |
| UI | Godot `Control` + `CanvasLayer` + Theme |
| 연출 | 2D `AnimationPlayer` + `Tween` + `ParallaxBackground` + `CanvasModulate` + `GPUParticles2D` + `VideoStreamPlayer`(사전 렌더 영상) |
| 결제 | Google Play Billing / Apple StoreKit / GodotSteam (`addons/godotsteam`) |
| 광고 (모바일) | AdMob Godot plugin |

---

## 12. 관련 문서

- `docs/prd.md` — PRD
- `docs/design/game_overview.md` — 풀 개요 + 벤치마크
- `docs/design/pitch_10min.md` — 10분 피치덱
- `docs/contents.md` — 100 목적지 콘텐츠
- `docs/launch_balance_design.md` — 확률 / 보상 곡선
- `docs/destination_config.md` — 목적지 / 도감 / 뱃지 / 마스터리 구조
- `docs/bm.md` — 수익 모델 상세
- `docs/social_bm.md` — 메타 보너스 (싱글 리텐션)
- `docs/flow.md` — 게임 흐름 (Godot 씬 매핑)
- `docs/launch_sky_transition_plan.md` — Sky Transition 시스템
- `docs/rocket_launch_implementation_spec.md` — 발사 시스템 구현 사양
- `docs/ui_design_guide.md` — UI 디자인 가이드
- `docs/systems/INDEX.md` — 시스템 카탈로그
- `docs/system_mapping_analysis.md` — Godot 시스템 아키텍처 개요
- `docs/plan.md` — 14주 개발 로드맵
