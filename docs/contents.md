# Star Reach: 우주 탐사 100+ 스테이지 기획 (Game Contents)

이 문서는 플레이어가 지구 표면에서 출발하여 관측 가능한 우주의 끝까지 나아가는 여정을 **천문학적 거리 순으로 100개 이상의 목적지(Destination)** 로 세분화하여 기획한 문서입니다.
각 구역(Zone)별 대표적인 **2D 배경 레이어 / 사전 렌더 영상 컷** 과 환경(Environment) 테마를 공유하되, 세부 목적지마다 다단계 확률 판정(`requiredStages`)을 통과해 도달합니다.

> **연출 노트 (Godot 2D)**: 모든 Zone의 배경은 `ParallaxBackground` + `CanvasModulate` 색조 보간으로 표현. 마일스톤(10/25/50/75/100)과 일부 핵심 첫도달 목적지에는 `VideoStreamPlayer` 사전 렌더 영상(5~12초)을 1회 보상 컷으로 재생.

---

## Zone 1: 지구권 및 근지구 공간 (Earth Region)
대기권을 벗어나 지구 중력권 내의 주요 궤도들을 돌파합니다. 
*   **환경 테마:** 푸른 지구의 배경, 인공위성 잔해, 눈부신 태양광.

1. 대류권 (Troposphere) - 고도 10km
2. 성층권 (Stratosphere) - 상공 50km
3. **카르만 선 (Karman Line) - 상공 100km (우주의 시작)**
4. 극궤도 (Polar Orbit)
5. 저궤도 위성망 (LEO Satellite Constellations)
6. 허블 우주 망원경 (Hubble Space Telescope) - 상공 540km
7. **국제 우주 정거장 (ISS) - 상공 400km**
8. 밴 앨런 대 응집구역 (Van Allen Radiation Belt)
9. GPS 위성 궤도 (Medium Earth Orbit) - 상공 20,200km
10. 정지 궤도 (Geostationary Orbit) - 상공 35,786km

---

## Zone 2: 지구-달 시스템 및 근지구 천체 (Lunar & NEO)
지구를 확실히 벗어나 달 표면과 그 너머 근접 소행성들을 만납니다.
*   **환경 테마:** 칠흑 같은 우주, 거친 질감의 회색 달 표면, 지나가는 소행성들.

11. 달 전이 궤도 (Translunar Injection)
12. 게이트웨이 정거장 예정지 (Lunar Gateway Orbit)
13. 고요의 바다 (Sea of Tranquility) - 아폴로 11호 착륙지
14. 폭풍의 대양 (Oceanus Procellarum)
15. 티코 크레이터 (Tycho Crater)
16. 달의 뒷면 (Far Side of the Moon)
17. 라그랑주 점 L1 (Lagrange Point L1)
18. 제임스 웹 우주 망원경 (JWST - 라그랑주 점 L2)
19. 소행성 아포피스 (Asteroid 99942 Apophis)
20. 소행성 베누 (Asteroid Bennu - 오시리스-렉스 탐사지)

---

## Zone 3: 내행성계 (Inner Solar System)
금성과 수성, 그리고 화성과 그 위성들을 거치는 불타거나 메마른 행성 지역입니다.
*   **환경 테마:** 화성의 암석 사막, 수성의 작열하는 태양, 금성의 두꺼운 황산 구름.

21. 화성 전이 궤도 (Mars Transfer Orbit)
22. 데이모스 (Deimos) - 화성의 제2 위성
23. 포보스 (Phobos) - 화성의 제1 위성
24. **화성 올림푸스 산 (Mars, Olympus Mons)**
25. 마리네리스 협곡 (Valles Marineris)
26. 얼음 덮인 화성 극관 (Martian Polar Ice Caps)
27. 금성 궤도 진입 (Venus Orbit)
28. 마테우스 분화구 (Maat Mons, Venus)
29. 수성 궤도 (Mercury Orbit)
30. 칼로리스 분지 (Caloris Basin, Mercury)

---

## Zone 4: 주 소행성대 및 왜소행성 (Asteroid Belt & Ceres)
화성과 목성 사이에 넓게 퍼진 바위와 먼지의 바다입니다.
*   **환경 테마:** 화면을 가득 채운 온갖 크기의 운석 모델, 충돌을 피하는 듯한 연출.

31. 화성-목성 간 암석 평원 (Inner Asteroid Belt)
32. 소행성 에로스 (Eros)
33. 소행성 가스프라 (Gaspra)
34. 소행성 이다와 위성 닥틸 (Ida & Dactyl)
35. 소행성 마틸데 (Mathilde)
36. 금속 소행성 프시케 (16 Psyche) - 황금빛 소행성
37. 소행성 베스타 (4 Vesta)
38. **왜소행성 세레스 (Ceres) - 얼음 화산 아후나 몬스**
39. 힐다 소행성군 (Hilda Group)
40. 목성 트로이 소행성군 (Jupiter Trojans)

---

## Zone 5: 목성계 (Jovian System)
태양계 최대의 가스 행성과, 각자 독특한 매력을 지닌 4대 갈릴레이 위성들입니다.
*   **환경 테마:** 끔찍할 정도의 거대한 가스 폭풍, 유로파의 갈라진 얼음 표면, 이오의 용암 분출.

41. 목성 자력권 (Jupiter's Magnetosphere)
42. **목성 대적점 (Jupiter's Great Red Spot)**
43. 목성의 옅은 고리 (Jovian Ring System)
44. 위성 아말테아 (Amalthea)
45. **화산 위성 이오 (Io)** - 끊임없는 유황 분출 연출
46. 펠레 화산 (Pele Volcano, Io)
47. **얼음 위성 유로파 (Europa)** - 얼음 밑 바다를 암시하는 파란 균열
48. 위성 가니메데 (Ganymede) - 태양계에서 가장 큰 위성
49. 위성 칼리스토 (Callisto) - 크레이터로 뒤덮인 표면
50. 목성 궤도 외곽 (Outer Jovian System)

---

## Zone 6: 토성계 (Saturnian System)
가장 아름다운 고리와, 생명체 거주 가능성이 점쳐지는 위성 무리입니다.
*   **환경 테마:** 광활하게 뻗은 반투명 얼음 고리(Rings)와 타이탄의 호박색 마스킹 대기.

51. 토성 궤도 진입 (Saturn Orbit)
52. **토성의 거대 고리 A~F (Saturn's Rings)**
53. 토성 북극의 육각형 폭풍 (Saturn's Hexagon Storm)
54. 목동 위성 판 (Pan, The Shepherd Moon)
55. 위성 미마스 (Mimas) - '데스스타' 크레이터
56. **간헐천 위성 엔셀라두스 (Enceladus)** - 물기둥(Plume) 이펙트 연출
57. 위성 테티스 (Tethys)
58. 위성 디오네 (Dione)
59. 위성 레아 (Rhea)
60. **위성 타이탄 (Titan)** - 메탄 바다와 두꺼운 주황빛 대기

---

## Zone 7: 거대 얼음 행성계 (Ice Giants: Uranus & Neptune)
춥고 어두운 태양계 외곽의 신비로운 푸른빛 행성들입니다.
*   **환경 테마:** 에메랄드빛(천왕성)과 짙은 코발트블루(해왕성)의 가스 하늘.

61. 위성 이아페투스 (Iapetus, Saturn's Moon) - 명암이 극명한 호두 모양
62. 천왕성 궤도 (Uranus Orbit) - 90도 누워서 자전하는 연출
63. 위성 미란다 (Miranda) - 프랑켄슈타인 천체
64. 위성 아리엘 & 움브리엘 (Ariel & Umbriel)
65. 위성 티타니아 & 오베론 (Titania & Oberon)
66. 해왕성 궤도 (Neptune Orbit)
67. **해왕성 대암점 (Neptune's Great Dark Spot)**
68. 트리톤 (Triton) - 역행하는 얼음 화산 위성
69. 네레이드 (Nereid)
70. 해왕성 트로이 소행성군 (Neptune Trojans)

---

## Zone 8: 명왕성과 카이퍼 대 (Pluto, Kuiper Belt & Oort Cloud)
태양계 행성을 벗어난 얼음 바위들의 영역입니다. 태양은 조그만 별처럼 보입니다.
*   **환경 테마:** 칠흑 같은 우주, 날리는 얼음 결정, 극저조도의 쓸쓸한 환경.

71. **명왕성 (Pluto)** - 스푸트니크 평원 (하트 모양 지형)
72. 위성 카론 (Charon)
73. 닉스 & 히드라 (Nix & Hydra)
74. 소행성 아로코스 (Arrokoth) - 눈사람 모양 천체
75. 왜소행성 하우메아 (Haumea) - 빠르게 회전하는 타원형 천체
76. 왜소행성 마케마케 (Makemake)
77. 왜소행성 에리스 (Eris)
78. 위성 디스노미아 (Dysnomia)
79. 카이퍼 대 외곽 (Scattered Disc)
80. **오르트 구름 (Oort Cloud)** - 수조 개의 혜성의 고향

---

## Zone 9: 근거리 성간 우주 & 외계 행성 (Interstellar & Exoplanets)
태양계를 완전히 벗어나, 인간에게 친숙하게 들리는 이웃 항성(가장 가까운 별)들로 향합니다.
*   **환경 테마:** 다채로운 성간 가스와 항성들의 눈부신 광휘.

81. 헬리오스피어 이탈 (Heliopause Crossing) - 태양풍의 끝자락
82. 켄타우루스자리 프록시마 (Proxima Centauri) - 태양계에서 가장 가까운 별 (4.2광년)
83. **프록시마 b (Proxima b)** - 지구와 유사한 외계 행성 도달
84. 알파 센타우리 A & B (Alpha Centauri Binary Star)
85. 바너드 별 (Barnard's Star)
86. 시리우스 (Sirius) - 밤하늘에서 가장 밝은 별 (8.6광년)
87. 에리다누스자리 엡실론 (Epsilon Eridani)
88. 글리제 581 계 (Gliese 581 System) - 한때 생명체 존재를 기대했던 외계계
89. TRAPPIST-1 계 (TRAPPIST-1 System) - 7개의 지구형 행성계
90. 베가 (Vega) - 직녀성 (25광년)

---

## Zone 10: 우리 은하의 대명소들 (Milky Way Landmarks)
은하계 내의 화려한 성운, 초거성, 극단적인 우주 환경들입니다.
*   **환경 테마:** 압도적인 스케일의 성운(Nebula), 초거성의 눈먼 빛과 감마선 파티클.

91. 오리온 대성운 (Orion Nebula) - 빛나는 분홍/적색 가스 (1,344광년)
92. 말머리 성운 (Horsehead Nebula) - 유명한 암흑 성운의 실루엣
93. 플레이아데스 성단 (Pleiades Star Cluster) - 푸른 가슴을 품은 별 무리
94. 베텔게우스 (Betelgeuse) - 언제 폭발할지 모르는 진홍색 초거성
95. 독수리 성운 - 창조의 기둥 (Pillars of Creation, Eagle Nebula)
96. 마젤란 은하 (Magellanic Clouds) - 이웃 왜소 은하 동반자
97. 게 성운 (Crab Nebula) - 초신성 폭발의 잔해
98. 방출 성운 - 용골자리 성운 (Carina Nebula)

---

## Zone 11: 심우주와 궁극적 미지 (Deep Space & The Ultimate Frontier)
우주의 심장부로 진입합니다. 모든 것이 붕괴하고 일그러지는 궁극의 콘텐츠입니다.
*   **환경 테마:** 시공간이 일그러지는 렌즈 효과, 주변의 모든 형태가 빛의 선으로 왜곡되는 묘사.

99. 안드로메다 은하 (Andromeda Galaxy) - 250만 광년 떨어진 가장 큰 이웃 은하
100. 국부 은하군 외곽 (Edge of Local Group)
101. 퀘이사 (Quasar, 3C 273) - 우주에서 가장 밝게 빛나는 활동 은하핵
102. 은하 중심부 성단 (Galactic Center Star Cluster)
103. 궁수자리 A* (Sagittarius A*) - 우리 은하 중심의 거대 블랙홀 입구
104. **사건의 지평선 (Event Horizon)** - 블랙홀 강착원반 위, 시공간 렌즈 이펙트
105. **종착점: 웜홀 / 블랙홀 특이점 (Singularity / Wormhole)** - 게임 엔딩 컷.
