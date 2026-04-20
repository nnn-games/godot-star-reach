# 결제 플러그인 설치 상태

자동 다운로드·배치 완료. 실제 결제 연동까지 남은 사용자 단계를 아래 체크리스트에 정리.

## ✅ 완료 (AI가 처리)

| 플러그인 | 버전 | 소스 | 위치 |
|---|---|---|---|
| **GodotGooglePlayBilling** | 3.2.0 (2026-03-15) | [github.com/godot-sdk-integrations](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.2.0) | `addons/GodotGooglePlayBilling/` |
| **ios-in-app-purchase** | 0.3.0 (2026-01-26) | [github.com/hrk4649](https://github.com/hrk4649/godot_ios_plugin_iap/releases/tag/0.3.0) | `ios/plugins/ios-in-app-purchase/` |
| **GodotSteam GDExtension** | 4.18.1 (2026-04-04) | [codeberg.org/godotsteam](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.18.1-gde) | `addons/godotsteam/` |

`project.godot` 변경:
- `[android] gradle_build/use_gradle_build=true`
- `[editor_plugins] enabled=[...GodotGooglePlayBilling/plugin.cfg]`
- 신규 `steam_appid.txt` = `480` (Spacewar 테스트 ID; 실제 AppID로 교체 필요)

검증:
- `godot --headless --quit-after 3` 클린
- `godot --headless --script res://tools/smoke_test.gd` 11 scenes + 7 scripts + 3 resources OK
- `godot --editor --headless --quit-after 4` 클린

## ⚠️ 사용자 필수 수동 단계

### Android
- [x] ~~**Android Build Template 설치**~~ — 완료. `%APPDATA%/Godot/export_templates/4.6.2.stable/android_source.zip`을 `android/build/`에 수동 압축 해제 (에디터 메뉴의 "Install Android Build Template"과 동일 결과).
- [ ] **Play Console 앱 등록** — $25 1회. SKU 생성(`pack_coins_small` 등).
- [ ] **License testing 계정 등록** — 테스트 기기 Google 계정을 Internal testing에 추가.
- [ ] **Export Preset 확인** — `Export → Android → Options → Plugins` 탭에서 `GodotGooglePlayBilling` 체크됐는지 확인.

### iOS (macOS 빌드 머신 확보 후)
- [ ] **Apple Developer 가입** — $99/년.
- [ ] **App Store Connect 앱 등록** + SKU 생성.
- [ ] **Sandbox Tester 계정 생성** — 실기기 테스트용.
- [ ] **Xcode 링커 설정** — `StoreKit.framework` 자동 링크 확인.
- [ ] **Export Preset** — `Export → iOS → Options → Plugins`에서 `ios-in-app-purchase` 체크.

### Steam
- [ ] **Steamworks Partner 가입** — $100/앱.
- [ ] **AppID 할당** → `steam_appid.txt`를 실제 ID로 교체.
- [ ] **DLC 상품 등록** (광고 제거·스킨용) 또는 **MicroTransaction 설정** (코인 팩용).
- [ ] **Steam 클라이언트 실행 후 F5 테스트** — Steam 꺼져 있으면 Overlay·실제 결제 불가.

### 공통 (서버)
- [ ] **영수증 검증 서버** — Firebase Function 또는 Receipt Validator SaaS 선택.
- [ ] 각 플랫폼의 서버 검증 자격증명 발급:
  - Google Play Developer API 서비스 계정 JSON
  - Apple App-Specific Shared Secret
  - Steam WebAPI Publisher Key

## 🟡 알려진 이슈

- **첫 `--editor --headless` 실행이 가끔 크래시**: 플러그인을 새로 넣은 직후 first-scan 중 한 번. 재실행하면 정상. Godot 첫 통합 스캔의 일시적 이슈.
- **GodotSteam 실행 요구**: 런타임에 `Steam.steamInit()` 호출 시 Steam 클라이언트가 켜져 있어야 함. 개발 중 Steam 종료 상태로 F5 → `steamInit()` 실패는 정상(Backend가 처리).
- **Android Gradle 첫 빌드 느림**: Gradle 캐시 초기화로 5~10분 소요. 이후엔 빨라짐.

## 재다운로드 필요 시

```bash
# 최신 버전 확인
gh release list --repo godot-sdk-integrations/godot-google-play-billing --limit 3
gh release list --repo hrk4649/godot_ios_plugin_iap --limit 3
curl -s https://codeberg.org/api/v1/repos/godotsteam/godotsteam/releases?limit=3 | python -m json.tool
```

각 다운로드 URL은 이 문서 상단 테이블 참조. 임시 다운로드 캐시 `build/tmp-plugins/` 는 삭제 가능.

## 다음 단계 (Phase 4.0)

플러그인이 설치됐으므로 이제 **`IAPService` Autoload + `IAPProduct` Custom Resource + Mock/Android/iOS/Steam Backend**를 붙일 준비 완료. 지시 주시면 이어 진행합니다.
