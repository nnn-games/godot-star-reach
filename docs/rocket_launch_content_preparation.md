# 🚀 Star Reach 콘텐츠 구현 준비 체크리스트 (Godot)

> **목적**: `docs/game_concept_rocket_launch.md` + `docs/prd.md` 기준으로 실제 체험 구현(Godot 4.6)에 필요한 애셋과 선행 작업을 한 번에 정리한다.
> **작성일**: 2026-04-24
> **참고 문서**: `docs/game_concept_rocket_launch.md`, `docs/destination_config.md`, `docs/launch_sky_transition_plan.md`, `docs/ui_design_guide.md`, `docs/rocket_launch_implementation_spec.md`

---

## 1. 먼저 잠가야 하는 스코프

아래 항목이 확정되지 않으면 애셋 수량, 텍스트 작업량, 연출 범위가 계속 흔들린다.

| 결정 항목 | 현재 문서 상태 | 먼저 확정할 내용 |
|---|---|---|
| 목적지 수 | `docs/contents.md` 105개 정의됨 | V1 출시 활성 100개 (`T1~T5`) + 5개 (`T6 성간`)는 DLC `Interstellar Frontier`로 분리 |
| 티어 구조 | `T1~T5` 활성 + `T6` DLC | 확정 |
| 목적지 연출 단위 | 마일스톤 영상 5종 + Zone 첫진입 영상 + 일반 컷 | 확정 — 모든 목적지 영상화 X (도파민 루프 보호) |
| 로켓 비주얼 구조 | 모듈식 1기체 + 코스메틱 트레일/페인트로 표현 | 확정 |
| 교육 콘텐츠 밀도 | 카드형 요약 1줄 + 도감 상세 2~3줄 | 확정 |
| 확장 기능 범위 | DLC: Expansion (분기) + Cosmetic (코어 출시 후) | 확정 |

---

## 2. 준비해야 할 애셋

## 2.1 2D 배경 / 환경 애셋 (Godot `ParallaxBackground`)

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 메인 화면 배경 | 발사대 (간략 일러스트) + 컨트롤 패널 + 연료 탱크 | 1장 정적 배경 + 미세 애니 |
| Tier별 배경 레이어 | 5 Tier × 4~5장 (전경/중경/원경/별) = 약 25장 | `data/sky_profiles/*.tres`에서 참조 |
| Zone 색조 프로필 | 11 Zone × `CanvasModulate.color` + 알파 블렌딩 그라데이션 텍스처 | Tier 변형 규칙 적용 (채도/속도/zoom) |
| 발사대 스킨 | V1 기본 1종 + 시즌별 한정 4~6종 | 코스메틱 IAP / 시즌 컬렉션 |
| 발사대 코스메틱 마운트 포인트 | 발사대 스프라이트 위 트레일/장식 마운트 좌표 | `Position2D` 노드 |

## 2.2 VFX / 카메라 / 애니메이션 애셋 (Godot)

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 발사 VFX | 점화 화염, 연기, 충격파, 배기 트레일 | `GPUParticles2D` 프리셋 5종 |
| 실패 VFX | 폭발, 엔진 정지, 검은 연기, 자유낙하 잔해 | 단계별 실패 타입 5종 |
| 단계 VFX | 1단 분리, 2단 점화, 궤도 진입, 착륙/도달 | 단계 가독성 확보 |
| 목적지 VFX | 달성 빔, 도감 갱신 플래시, Tier 해금 연출 | `AnimationPlayer` 트랙 |
| 카메라 연출 | `Camera2D.zoom` 펄스, 스크린 셰이크, 화이트 페이드 | `scripts/util/screen_shake.gd` 헬퍼 |
| 사전 렌더 영상 5종 | 마일스톤 (10/25/50/75/100) + Zone 첫진입 11종 + 첫도달 핵심 5~10종 | `VideoStreamPlayer` + `.ogv`, 720p 24fps, ≤1.5Mbps, 5~12초 |

## 2.3 UI / 2D 애셋 (Godot `Control`)

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 핵심 HUD | LAUNCH 버튼 (대형 원형, 펄스), 단계 진행 바, 성공률, Stress 게이지, 현재 목적지 | `scenes/main/main_screen.tscn` |
| 메뉴 화면 | 목적지 선택 / Upgrade (Launch Tech + Facility) / Codex / Mission / Daily Reward / Settings | 7개 화면 (`docs/ui_design_guide.md` §6 참조) |
| 모달 | 오프라인 요약 / Daily Reward / 광고 시청 / IAP 구매 / Region Mastery 달성 | `PopupPanel` 노드 |
| 아이콘 | XP / Credit / TechLevel / Launch Tech 5종 / Facility 5종 / 미션 / IAP 카테고리 | SVG → `.svg.import` (Godot SVG 지원) 또는 PNG |
| 온보딩 UI | 첫 발사 가이드 / 첫 업그레이드 / 첫 클리어 / Daily Reward 첫 노출 | 첫 5분 내 강한 모달 금지 |
| IAP UI | 상품 카드 / 가격 표시 / 효과 미리보기 / 구매 확인 모달 / 영수증 검증 진행 | Mobile + Steam 양 트랙 |

## 2.4 사운드 애셋

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 발사 SFX | 카운트다운, 점화, 엔진 상승음, 단계 분리, 궤도 진입 | 단계감 강화 |
| 실패 SFX | 경고 알람, 엔진 이상, 폭발, 자유낙하 | 실패 원인 체감 |
| 성공 SFX | 성공 팬파레, 목적지 달성, Tier 해금, 엔딩 | 보상감 강화 |
| UI SFX | 클릭, 구매, 보상 수령, 팝업 열기/닫기 | 기본 UX 품질 |
| BGM | 메인 화면 / Tier별 (Atmosphere / Cislunar / Mars / Outer / Interstellar) | 5곡 + 시즌 한정 1~2곡, OGG q=4 압축, 한 곡 ≤90s 루프 |

## 2.5 텍스트 / 데이터 콘텐츠

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 목적지 데이터 | 이름, 설명, 흥미 사실, 보상, 해금 조건, Tier | `data/destination_config.tres` 100개 |
| 업그레이드 데이터 | Launch Tech 5종 / Facility 5종 + 레벨별 비용/효과 | `data/launch_tech_config.tres` + `data/facility_upgrade_config.tres` |
| 미션 데이터 | 일일 미션 풀 7종 + 주간 미션 5~10종 | `data/mission_config.tres` |
| 도감 / 뱃지 / 마스터리 | 12 Codex 엔트리 + 19 Badge + 11 Region Mastery 5단계 | `data/codex_config.tres`, `data/badge_config.tres`, `data/region_mastery_config.tres` |
| IAP 상품 | 13개 IAP + 8개 Steam DLC + 1개 Subscription + Battle Pass 시즌 | `data/iap_config.tres`, Steamworks 백오피스 등록 |
| 튜토리얼 텍스트 | 첫 발사, 첫 업그레이드, 첫 성공, Daily Reward 안내 | 첫 5분 단계 가이드 |
| 다국어 리소스 | KO / EN 1차 (V1) / JP / DE / FR (V2) | `tr()` + `translation/*.po` |

## 2.6 라이브옵스 / 확장용 애셋

| 분류 | 준비 항목 | 비고 |
|---|---|---|
| 시즌 컬렉션 | 분기별 트레일 / 발사대 / 칭호 한정 코스메틱 | S01 Lunar Apollo / S02 Mars Era / S03 Voyager / S04 JWST |
| Battle Pass | 시즌 50 티어 보상 + 시즌 한정 영상 | `data/battle_pass_config.tres` |
| Expansion DLC | "Interstellar Frontier" — Zone 5개 + 목적지 25개 + 신규 영상 + 신규 BGM | V1 출시 후 6개월 |

---

## 3. 선행 작업

## 3.1 기획 / 밸런스 선행 작업

- 목적지 활성 범위 잠금 — `T1~T5 = 100개` (`T6 성간`은 DLC로 분리)
- 5 Tier 구조와 각 Tier의 단계 수 / 해금 조건 / 보상 테이블 통일 — `data/launch_balance_config.tres` + `data/destination_config.tres`
- 온보딩 수치 확정 — 첫 2~3회 100% 보정, 첫 업그레이드 무료 또는 매우 저렴
- XP / Credit / TechLevel / Pity / Stress / Auto Launch 경제 밸런스 시트 고정
- 실패 연출 5종 정의 (단순 폭발 1종이 아닌 단계별 실패 타입)
- IAP 가격 / Steam DLC 가격 / 구독 가격 1차 확정 — `docs/bm.md` 참조

## 3.2 콘텐츠 데이터 선행 작업

- `data/destination_config.tres` 스키마 확정 (이름, 한국어명, 설명, 흥미 사실, 영상 ID, 마스터리 카운트 포함 여부)
- 업그레이드 / 미션 / 뱃지 / IAP 데이터 공통 템플릿
- KO / EN 다국어 키 규칙 (`tr("D_03_NAME")`, `tr("LAUNCH_TECH_ENGINE_PRECISION_DESC")` 등)
- 목적지와 영상 / 마일스톤 / 뱃지 연결 표
- 교육 텍스트 길이 기준 — 카드 요약 1줄 + 상세 설명 2~3줄

## 3.3 아트 파이프라인 선행 작업

- 스타일 보드 — 우주 사실주의 vs 캐주얼 일러스트 톤 결정 (캐주얼 권장 — 모바일 친화)
- 로켓 모듈 규격 — 부스터 / 탱크 / 엔진 / 페어링 교체 마운트 포인트
- 메인 화면 그레이박스 → 최종 일러스트 단계 분리
- VFX 품질 기준 + 모바일 성능 예산 — 동시 파티클 수 (모바일 ≤100), 텍스처 ≤1024x1024, ASTC 4x4 압축
- 사전 렌더 영상 템플릿 — 공통 시작/종료 페이드 + 타이밍 재사용
- Steam Deck 가독성 — 폰트 최소 14sp, 안전 영역 확보

## 3.4 클라이언트 선행 작업 (Godot)

- `LaunchService`, `LaunchSessionService`, `StressService`, `DestinationService` 시그널 규격 확정 — `EventBus` 시그널 일람 작성
- 단계 시작 / 성공 / 실패 / 전체 성공 시점에 UI / VFX / Audio가 받을 시그널 페이로드 문서화
- `data/destination_config.tres` 필드 ↔ UI 카드 필드 매칭
- 텔레메트리 힌트 / Stress 정비 / Auto Launch 해금 흐름 → 화면 상태 매핑
- 도감 갱신 / 뱃지 지급 / 베스트 기록 반영 타이밍 정합성 확인
- IAP / Subscription / 광고 SDK 통합 PoC (Phase 1.5 목표) — `iap_service.gd` 베이스 + 플랫폼 어댑터 더미 호출

## 3.5 QA / 운영 선행 작업

- 첫 5분 퍼널 테스트 기준 — 첫 발사, 첫 업그레이드, 첫 성공, Daily Reward 첫 노출
- 모바일 저사양 환경에서 발사 VFX와 카메라 흔들림 허용 범위 검증 (Android Go 디바이스 등)
- iOS / Android 다양한 화면 비율 (16:9 / 19.5:9 / 폴더블) UI 안전 영역 검증
- Steam Deck 컨트롤러 입력 + 720p 가독성 검증
- 연속 실패 구간과 Pity System 체감 여부 로그 확인
- 목적지 해금 속도 / 이탈 구간 / 업그레이드 구매 전환율 / IAP 전환율 텔레메트리

---

## 4. 권장 제작 순서

1. **스코프 잠금** — 목적지 100, Tier 5, 영상 5+11, 영상 외 일반 컷
2. **데이터 템플릿 작성** — 목적지 / 업그레이드 / 미션 / 뱃지 `.tres` 스키마 고정
3. **그레이박스 제작** — 메인 화면 + 임시 로켓 + UI 와이어프레임
4. **코어 연출 구현** — 발사 VFX (Phase 3) + 실패 연출 + `Camera2D` 템플릿 + 결과 모달
5. **콘텐츠 본작업** — 100 목적지 데이터 입력 + 도감 12 엔트리 + 마일스톤 영상 5종 1차 작업
6. **메타 기능 연결** — Daily Reward / Mission / 도감 / 뱃지 / 마스터리
7. **IAP / 광고 / 구독 통합** — Phase 6
8. **폴리싱** — 사운드 / 성능 최적화 / 초반 밸런스 / 다국어 / 튜토리얼

---

## 5. 바로 착수해도 되는 최소 우선순위

- `T1~T5` 구간 잠금 (100 목적지 활성)
- 메인 화면 그레이박스 + 임시 로켓 스프라이트 1종
- 발사 카메라 (`Camera2D.zoom` + shake) 템플릿 1종
- HUD / 결과 모달 / Upgrade 화면 와이어프레임
- `data/destination_config.tres` 템플릿 확정 후 T1 5개만 먼저 작성
- 엔진 점화 / 폭발 / 성공 팬파레 사운드 우선 수급
- 마일스톤 영상 1종 (D_03 카르만 선) PoC

이 7개가 끝나면 실제 플레이 가능한 수직 슬라이스(vertical slice) 제작이 가능하다.
