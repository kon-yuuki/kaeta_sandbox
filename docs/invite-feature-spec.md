# 招待機能 仕様整理（目標 / 現状）

作成日: 2026-02-14

## 1. 目的
招待リンク経由でチーム参加を完了し、初回ユーザーが迷わず利用開始できる状態にする。

## 2. 対象範囲
- 招待リンクの発行
- リンクタップ時の遷移（Universal Links / カスタムスキーム）
- 招待参加画面
- 招待ユーザー向けオンボーディング
- 参加確定処理
- 未インストール時の導線（Webフォールバック）

## 3. 目指す仕様（To-Be）
| 項目 | 目指す仕様 |
|---|---|
| 招待リンク形式 | `https://kaeta-jointeam.com/invite/{inviteId}` を発行 |
| アプリインストール済み（iOS） | リンクタップでブラウザを挟まずアプリ起動、招待参加画面へ遷移 |
| 招待参加画面 | チーム名・招待者名を表示し、`参加してはじめる` で次に進める |
| 招待ユーザーのオンボーディング | `ユーザー情報 → アイコン設定 → 通知設定`（`家族を招待` は表示しない） |
| 招待参加確定 | オンボーディング完了時に `family_members` へ参加登録し、`profiles.current_family_id` を更新 |
| 招待リンク無効化 | 参加成功時に該当 `inviteId` を無効化（削除） |
| 未インストール時 | 招待URLから TestFlight（公開後は App Store）へ遷移できる |
| フォールバック | Universal Linkが失敗する環境向けに `kaeta://invite/{inviteId}` でも参加可能 |

## 4. 現状仕様（As-Is）
| 項目 | 現状 |
|---|---|
| 招待リンク発行 | 実装済み。`families_repository.dart` で `https://kaeta-jointeam.com/invite/{id}` を生成 |
| 招待情報取得 | 実装済み。`invitations` をSupabaseから取得し期限チェック |
| アプリ内遷移 | 実装済み。`AppLinkHandler` で `inviteId` を拾い `InviteStartPage` へ遷移 |
| 招待参加画面 | 実装済み。`InviteStartPage` でチーム名/招待者表示、`参加してはじめる` あり |
| 招待オンボーディング | 実装済み。`OnboardingFlow` で招待時は3ステップ表示、`TeamInviteStep` 除外 |
| 参加確定 | 実装済み。オンボーディング完了時に `joinFamily(familyId, inviteId)` を実行 |
| カスタムスキーム | 実装済み。`kaeta://invite/{id}` をInfo.plistに設定、アプリ側で受信対応 |
| AASA配信ファイル | リポジトリ内 `deeplink_hosting` に定義あり（`/.well-known` と root） |
| 未インストール導線 | アプリコード側では未対応。Web側（Cloudflare Worker）実装が必要 |

## 5. 既知のギャップ / リスク
| ID | 内容 | 影響 | 優先度 |
|---|---|---|---|
| G-01 | `https` タップ時に一部環境でブラウザ滞留（特にアプリ内ブラウザ） | 参加率低下 | 高 |
| G-02 | `/invite/*` のWebレスポンスが単純文言のみだと、未インストール時の導線がない | 新規流入損失 | 高 |
| G-03 | Android `assetlinks.json` が空 | Android App Links未整備 | 中 |
| G-04 | Universal LinkのOSキャッシュにより設定変更反映が遅延 | 検証混乱 | 中 |

## 6. 実装済みコードの主な参照先
- `lib/data/repositories/families_repository.dart`
- `lib/core/app_link_handler.dart`
- `lib/pages/invite/view/invite_start_screen.dart`
- `lib/pages/invite/providers/invite_flow_provider.dart`
- `lib/pages/onboarding/onboarding_flow.dart`
- `lib/pages/onboarding/widgets/profile_setup_step.dart`
- `lib/pages/onboarding/widgets/team_invite_step.dart`
- `lib/pages/onboarding/widgets/complete_step.dart`
- `ios/Runner/Runner.entitlements`
- `ios/Runner/Info.plist`
- `deeplink_hosting/.well-known/apple-app-site-association`
- `deeplink_hosting/apple-app-site-association`
- `deeplink_hosting/_headers`

## 7. 残タスク（推奨）
1. Cloudflare Worker（`/invite/*`）にフォールバックHTMLを実装する。
2. フォールバックで `kaeta://invite/{id}` を試し、失敗時に TestFlight へ遷移する。
3. TestFlight公開後、外部テスターで以下をE2E確認する。

## 8. 受け入れ確認シナリオ
1. インストール済み端末で `https://.../invite/{id}` をタップし、`InviteStartPage` が開く。
2. `参加してはじめる` でオンボーディングに進み、`家族を招待` が表示されない。
3. 名前・アイコン設定が完了後にプロフィールへ反映される。
4. 完了時に対象チームへ参加済みになる。
5. 未インストール端末で同リンクをタップし、TestFlightへ遷移する。

買い物メモアプリで一緒にリストを共有しましょう！
こちらのリンクから家族グループ「実家」に参加できます。

https://kaeta-jointeam.com/invite/61dab971-de89-4c4f-9c4e-22a813b492e5

開けない場合: kaeta://invite/61dab971-de89-4c4f-9c4e-22a813b492e5

有効期限: 2026/2/21 16:29