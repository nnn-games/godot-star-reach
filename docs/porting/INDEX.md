# Star Reach — 게임 플레이 기획서 (systems 1~4)

> **작성일**: 2026-04-24
> **문서 유형**: 기획서 인덱스
> **출처**: `docs/systems/` 기술 레퍼런스의 1~4 카테고리를 **플레이어 경험 / 디자인 의도 / 밸런스 관점**으로 재서술
> **용도**: 신규 합류자, 외부 협업자, 디자인 의사결정 검토

---

## 0. 왜 별도 문서인가

`docs/systems/`의 1~4 카테고리 문서는 **구현 레퍼런스** (Godot Autoload / Resource / Signal / `.tscn` 경로 중심). 본 폴더의 4개 문서는 같은 내용을 **게임 플레이 기획서 포맷** (플레이어 경험, 디자인 의도, 밸런스 수치, 튜닝 포인트)으로 재서술해:

- 코드를 열지 않고도 게임을 이해할 수 있고,
- 디자인 의사결정의 *왜*를 놓치지 않으며,
- 기획 검토 / 외부 공유 / QA 학습 시 단일 진입점이 되도록 한다.

---

## 1. 문서 구성

| 번호 | 문서 | 대응 systems | 핵심 주제 |
|---|---|---|---|
| 01 | [Launch Core](01-launch-core.md) | 1-1 ~ 1-4 | 발사 루프, 확률 엔진, 자동 발사 + 오프라인 진행, 스트레스 |
| 02 | [Progression](02-progression.md) | 2-1 ~ 2-5 | 100 목적지, 11 지역, 프로그램 레벨, 2종 업그레이드 축 |
| 03 | [Economy](03-economy.md) | 3-1 ~ 3-2 | 3화폐 경제, 완료 보상 파이프라인 |
| 04 | [Cinematic / Visual](04-cinematic-visual.md) | 4-1 ~ 4-3 | 2D 시네마틱, Sky Transition, VFX + 사전 렌더 영상 |

---

## 2. 시스템 의존 관계 요약

```
[Launch Core]
 ├─ Launch Session (1-1) ─────────┐
 ├─ Multi-Stage Probability (1-2) ┤
 ├─ Auto Launch + Offline (1-3) ──┤  → Stage 성공/실패, 목적지 완료 시그널 (EventBus)
 └─ Stress / Abort (1-4) ─────────┘
                              ↓
[Progression]
 ├─ Destination (2-1)   ← 완료 시 허브 역할, 아래 전부 오케스트레이션
 ├─ Region (2-2)        ← 첫도달 / 마스터리
 ├─ Program Lv. (2-3)   ← 해금 축
 ├─ Launch Tech (2-4)   ← XP 소비 (세션형)
 └─ Facility (2-5)      ← Credit 소비 (영구형)
                              ↓
[Economy]
 ├─ 3화폐 (3-1)         ← XP / Credit / TechLevel
 └─ 완료 보상 (3-2)      ← 단일 시그널 페이로드로 모든 보상 지급
                              ↓
[Cinematic / Visual]
 ├─ Main Scene Cinematic (4-1)  ← Camera2D zoom + shake + Sprite2D Tween
 ├─ Sky Transition (4-2)        ← ParallaxBackground + CanvasModulate Tween
 └─ Launch VFX (4-3)            ← GPUParticles2D + 사전 렌더 영상 (마일스톤)
```

---

## 3. 핵심 수치 요약

### 확률 구간 (1-2)

| 티어 | 스테이지 | base | max |
|---:|---:|---:|---:|
| 1 | 3~4 | 50% | 85% |
| 2 | 5~6 | 44% | 78% |
| 3 | 7~8 | 36% | 72% |
| 4 | 9 | 28% | 66% |
| 5 | 10 | 22% | 60% |

### 성공률 최대 보정

| 소스 | 최대 기여 |
|---|---:|
| Launch Tech `engine_precision` | +40%p |
| Facility `engine_tech` | +10%p |
| IAP Guidance Module Pass (영구) | +5%p |
| IAP Trajectory Surge (30분 시간제) | +3%p |
| **상시 합계 (Surge 제외)** | **+55%p** |
| **Surge 활성 일시 합계** | **+58%p** |

### 자동 발사 rate (1-3)

```
base 1.0 + IAP Auto Launch Pass(+0.35) + IAP Auto Fuel(+0.50)
cap 2.5 launches/sec
```

### 오프라인 진행 캡 (1-3)

- 자동 발사 해금 후: 8h
- 자동 발사 미해금: 0~1h

### 스트레스 티어별 (1-4)

| 티어 | 실패당 +스트레스 | Abort 확률 | Repair Cost |
|---:|---:|---:|---:|
| 3 | +10 | 40% | 300 C |
| 4 | +15 | 50% | 700 C |
| 5 | +20 | 60% | 1,500 C |

### 완료 보상 최대 배수 (3-2)

| 화폐 | 기본 | 최대 배수 | 배수 성분 |
|---|---|---:|---|
| Credit | reward_credit | **2.0x** | (1 + mission_reward 100%) |
| TechLevel | reward_tech_level | **1.5x** | (1 + tech_reputation 50%) |

---

## 4. 3화폐 원칙 (요약)

```
XP        → 세션 내부 순환, 목적지 변경 시 리셋
Credit    → 영구 성장, Stress 정산
TechLevel → 단조증가, 해금 축 (직접 판매 IAP 절대 금지)
```

**금지된 경로**:
- XP → Credit 변환 ❌
- Credit → TechLevel 변환 ❌
- TechLevel 즉시 지급 IAP ❌

---

## 5. 주요 디자인 의사결정

| 주제 | 결정 | 이유 |
|---|---|---|
| 발사 진입점 | 메인 화면 직접 LAUNCH | 모바일 / Steam 한 손 조작에 최적화 |
| 스테이지 시간 | 2.0s 고정 | 1초 연출 부족, 3초 템포 지루 |
| 실패 시 루프 중단 | 즉시 break | "마지막 단계만 재시도" 확률 의미 퇴색 |
| Stress 시작 티어 | T3 | T1부터 켜면 신규 이탈, T4는 너무 늦음 |
| Auto Launch 해금 | OR 조건 2개 | 강제 IAP 요구 UX 저항 |
| 보상 파이프라인 | 단일 시그널 | UI/VFX/Audio 모두 자체 구독 |
| 환경 연출 | 2D ParallaxBackground + 사전 렌더 영상 | 모바일/Steam 동시 안정 + 핵심 영상 임팩트 |
| TechLevel 직접 판매 IAP | 절대 금지 | P2W 방어선 (단조 증가축) |
| Steam 광고 / 가챠 | 없음 | PC 게이머 문화 충돌 |

---

## 6. 신규 합류자가 제일 먼저 읽을 순서

1. **01 Launch Core** — "한 판"이 어떻게 만들어지는가
2. **02 Progression** — "왜 또 누르는가" + 5개 성장 축
3. **03 Economy** — 화폐 규칙과 보상 파이프라인
4. **04 Cinematic / Visual** — 이 모든 것이 어떻게 감각적으로 전달되는가

이후 카테고리 5~8 (Meta / Meta Bonus / Monetization / Shell)은 `docs/systems/` 직접 참조.

---

## 7. 관련 디자인 문서 (정본)

- `docs/design/game_overview.md` — 전체 게임 개요
- `docs/design/pitch_10min.md` — 10분 피치덱
- `docs/prd.md` — PRD
- `docs/contents.md` — 100 목적지 콘텐츠
- `docs/launch_balance_design.md` — 확률 / 보상 곡선
- `docs/destination_config.md` — 목적지 / 도감 / 뱃지 / 마스터리 구조
- `docs/bm.md` — IAP / DLC / Subscription / Battle Pass 사양
- `docs/social_bm.md` — 메타 보너스 (싱글 리텐션)
- `docs/systems/INDEX.md` — 시스템 카탈로그 (29 시스템 / 8 카테고리)
- `docs/systems/ARCHITECTURE.md` — Mermaid 다이어그램 (11종)
- `docs/system_mapping_analysis.md` — Godot 시스템 아키텍처 개요
- `docs/plan.md` — 14주 개발 로드맵
- `docs/flow.md` — 게임 흐름 (Godot 씬 매핑)
