# WORK TASK SHEET

更新日: 2026-04-15

## 運用ルール

- 現在の残タスクはこのファイルに集約する。
- 完了済みの詳細履歴は `docs/COMPLETED_TASKS.md` や各仕様書を参照する。
- 通知の理想仕様移行は完了済みのため、このシートでは管理しない。
- タスクは `実装が必要` / `確認のみ` / `判断のみ` に分けて管理する。

## 実装が必要

### P1. 認証 / 招待

- [ ] A-08 設定画面から後付けでメール・Google・Appleアカウント連携ができるよう修正
  - 後からメール認証、後から Google 認証、後から Apple 認証を分けて確認する
  - Google 連携後に `kaeta-jointeam.com` へ遷移せずアプリへ戻ること
  - Apple 連携で Face ID 後の登録失敗が起きず、連携完了できること
  - 後からメール認証したときに `Change email` 後、`kaeta-jointeam.com` ではなくアプリへ戻ること
- [ ] A-15 アプリ起動中に招待リンクを踏んだとき、アプリへ遷移しても「参加してはじめる」画面が表示されない問題を修正
  - フォアグラウンド / バックグラウンドの両方で該当の `参加してはじめる` 画面を表示する
- [ ] A-16 チーム未所属状態でアカウント削除したときも、ゲストモードへ残らずスタート画面へ遷移するよう修正
- [ ] A-17 Cloudflare Worker の `/invite/*` にフォールバックHTMLを実装する
  - `kaeta://invite/{id}` を試し、失敗時に TestFlight へ遷移する
- [ ] A-18 iOS 認証セッションの保存先を SharedPreferences から Keychain へ移行する
  - `flutter_secure_storage` を追加し、Supabase Auth の `LocalStorage` を SecureStorage 実装へ差し替える
  - iOS は Keychain を使い、`KeychainAccessibility.first_unlock_this_device` 相当の設定を採用する
  - 既存の `sb-<project-ref>-auth-token` が SharedPreferences にある場合は、初回起動時に SecureStorage へ移行する
  - 移行後は旧 SharedPreferences の認証セッションキーを削除する
  - ログアウト時に SecureStorage 側の session が削除されることを確認する
  - 既存ログイン済みユーザーがアップデート後に原則ログアウトされないことを確認する
  - PowerSync が `currentSession.accessToken` 経由で引き続き接続できることを確認する
  - `flutter analyze` が通ることを確認する

### P2. オフライン挙動

- [ ] O-01 アイテム追加 / 更新 / 完了のオフライン受け入れ条件を明文化する
- [ ] O-02 アイテム操作に付随するオンライン依存処理を棚卸しする

## 確認のみ

### P2. オフライン挙動

- [ ] O-03 オフライン中にテキストのみのアイテム追加が成立し、アプリ再起動後もローカル表示が残ることを確認する
- [ ] O-04 オフライン中にアイテム完了 / 再追加が成立し、オンライン復帰後に Supabase 側へ同期されることを確認する
- [ ] O-05 オフライン中にカテゴリ付きアイテム追加を行ってもローカル状態が壊れないことを確認する
- [ ] O-06 PowerSync 同期再開後、オフライン中のアイテム変更が欠落なくサーバーへ反映されることを確認する
- [ ] O-07 オフライン中の画像付き追加の挙動が、定義した方針どおりになることを確認する
  - 当面は「画像なしで保存し、アイテム本体だけ通す」方針
- [ ] O-08 オフライン中に漢字名アイテムを追加した場合、ふりがな pending queue に積まれて後から更新されることを確認する

### P3. 通知運用 / 通知設定

- [ ] N-01 オフライン中にアイテム追加してもアプリが落ちず、通知要求が queue に保存されることを確認する
- [ ] N-02 オンライン復帰後、保存済み queue が flush されて `notification_jobs` に反映されることを確認する
- [ ] N-03 オフライン中に複数件追加した場合でも、再送時に重複や欠落が起きないことを確認する
- [ ] N-04 アプリ再起動後も queue が残り、オンライン復帰で再送されることを確認する
- [ ] N-06 アイテム追加で `notification_jobs` に `pending` が増えることを定期確認する
- [ ] N-07 worker 実行で `pending -> sent/failed` に遷移することを確認する
- [ ] N-08 失敗時に `last_error` に理由が残ることを確認する
- [ ] NS-01 個別トグル OFF の通知種別で push が届かないことを確認する
- [ ] NS-02 個別トグル ON の通知種別は引き続き正常に push が届くことを確認する
- [ ] NS-04 複数端末がある場合、端末ごとに設定が独立して機能することを確認する

## 判断のみ

### P3. 通知運用

- [ ] N-05 `partial_failure` を独立 status に昇格するか運用判断を確定する
  - `delivery_summary` で見るだけにするか、schema / worker / 監視SQLまで反映するかを決める

## 参考

- 通知仕様: `docs/notification-spec.md`
- 通知の現在挙動: `docs/NOTIFICATION_CURRENT_BEHAVIOR.md`
- Push 状態メモ: `docs/push-worker-status.md`
- 課金仕様: `docs/BILLING_PLAN_SPEC.md`
- 招待仕様: `docs/invite-feature-spec.md`
- 完了済みタスク: `docs/COMPLETED_TASKS.md`
