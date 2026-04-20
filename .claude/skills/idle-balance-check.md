---
name: idle-balance-check
description: Sanity-check the incremental simulator balance — cost curves, time-to-next-upgrade, rate scaling, offline cap reasonableness. Reads data/*.tres and reports anomalies.
---

# /idle-balance-check

증분 시뮬레이터의 밸런싱 데이터가 "재미있는 범위"에 있는지 점검합니다.

## 목표 지표 (기본값, 기획 변경 시 이 문서를 갱신)

| 지표 | 바람직한 범위 | 이유 |
|---|---|---|
| 초기 업그레이드 텀 | 10s ~ 60s | 첫 피드백 루프가 너무 빠르거나 느리면 이탈 |
| 10 레벨까지 누적 시간 | 5min ~ 30min (초기 tier) | 세션 첫 집중력 시간에 수렴 |
| 비용 성장률(`cost_growth`) | 1.07 ~ 1.20 | 일반적 증분겜 관례 |
| 생성기 수 | 5 ~ 12 (단일 tier) | 선택 피로 vs 깊이 |
| 오프라인 캡 | 2h ~ 12h | 너무 길면 상시 플레이 유인 저하 |
| 초기 수익/비용 비 | 1:2 ~ 1:5 | 너무 쉬우면 긴장 상실 |

## 작업 절차

1. `star-reach/data/generators/*.tres` 를 읽어 다음 필드 추출:
   - `base_cost`, `cost_growth`, `base_rate`, 연결된 `currency` id
2. 각 생성기별로 계산:
   - **첫 구매 시간** = `base_cost / (이전 생성기 총 rate)` (첫 생성기는 수동 가정 1 click/sec)
   - **10 레벨까지 누적 비용** = `base_cost * (cost_growth^10 - 1) / (cost_growth - 1)`
   - **10 레벨 도달 시 생산 rate**
3. 목표 지표와 비교 → 벗어나는 항목을 `WARN` / `FAIL` 로 표시.
4. 표 형태 리포트 출력:

```
[generator: miner]
  first_buy_time:  12s     [OK]
  t_to_10:         8m 20s  [OK]
  cost_growth:     1.15    [OK]
  rate_at_lv10:    45/s    [OK]
```

5. 균형이 맞지 않으면 **조정 제안**을 같이 제시 (예: `base_cost` 를 2배로, `cost_growth` 를 1.18로).
6. 기획서가 확정되어 장르 관례와 다른 목표가 생기면, 이 파일 상단의 표를 먼저 갱신하고 작업.

## 주의

- 실제 게임 감각은 수식만으로 완결되지 않음. 숫자 리포트는 **가설 검증용** 으로만.
- 사용자 승인 없이 `.tres` 를 자동 수정하지 말 것. 제안만.
