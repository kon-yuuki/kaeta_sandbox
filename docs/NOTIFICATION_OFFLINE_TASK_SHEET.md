# NOTIFICATION & OFFLINE TASK SHEET

更新日: 2026-03-29

## 目的

- 通知まわりとオフライン対応の未完了タスクを他領域から分離して管理する
- push 配信基盤、オフライン時の振る舞い、運用判断、確認観点を 1 枚で追えるようにする

## 現状整理

- アイテム追加や更新の本体データは Drift + PowerSync のローカルDB経由で扱っており、設計上はオフライン追加後にオンライン復帰で同期する想定
- アイテム追加は `TodoRepository.addItem()` -> `ItemsRepository.getOrCreateItemId()` -> Drift 書き込みの流れでローカルDBへ先に反映する実装になっている
- PowerSync 側の Supabase 反映は `uploadData()` が後追いで行うため、アイテム本体はオンライン必須の作りではない
- ふりがな変換は Yahoo API を使うが、失敗時は `pending_hiragana_update_ids` に積んで後から再処理する実装がすでにある
- 一方で画像アップロードはネットワーク前提で、オフライン時の退避や再送設計はまだない
- 一方で家族通知は `NotificationsRepository` から Supabase RPC を即時実行しており、オフライン時のキュー保存や再送は未対応
- そのため、オフライン中にアイテム追加自体は成立しても、通知要求だけ失敗して欠落する可能性がある
- さらに、シミュレーター実機確認では `SocketException / ClientException` に加えて `database is locked` も発生しており、通知の例外処理不足とローカルDB競合の切り分けが必要

## 実装済み

- 家族通知の producer は `public.notify_family_members` に集約済み
- RPC は `public.app_notifications` を追加したうえで `public.notification_jobs` に job を積む
- Flutter 側の `NotificationsRepository` は家族モード時に `notify_family_members` RPC を呼ぶ
- `device_tokens` / `push_debug_logs` から対象端末のトークン同期は成功している
- `send-push` worker は本番稼働済みで、`pg_cron` による自動実行も確認済み
- `showTopSnackBar(..., saveToHistory: true, familyId: あり)` は server-side 通知配信へ流すよう更新
- `notification_jobs` の cleanup 方針を SQL 化
- `failed` jobs は `attempts < 3` の間、自動再送対象に更新
- 監視クエリを `docs/sql/notification_jobs_monitoring.sql` に追加
- `notification_jobs.delivery_summary` と `notification_job_delivery_logs` で、全成功 / 一部成功 / 全失敗を追跡できるよう更新
- `ItemsRepository` では、ひらがな変換失敗時の pending queue を `SharedPreferences` へ保存する実装がある
- `TodoRepository` / `ItemsRepository` のローカル書き込みに、`database is locked` 用の短い retry を追加済み

## 現在の残タスク

### Step 0. 理想通知への移行を推奨順で進める

#### 実装タスク

- [ ] I-00 既存通知と新規通知を、理想通知仕様へ推奨順で揃える
  - 方針:
    - まずは既存通知のうち、追加データを渡せば理想に一致できるものから着手する
    - その後に、専用イベントが未実装の通知を追加していく
    - Supabase 側の SQL / RPC 適用が必要なタイミングは都度明示する
- [x] I-01 全件購入完了通知を理想仕様に一致させる
  - 目標:
    - title: `{actorName}さんがすべての買い物を完了しました`
    - body: `{firstItemName}ほか{count}件を購入。アプリからスタンプを送れます`
  - 仕様変更メモ:
    - 最後の未完了アイテムが購入された瞬間に即時通知する
    - 通知件数 `{count}` は「前回までの一部購入完了通知で未カウントの購入分」に限定する
    - 直前 2 分以内に同一 user が購入していて、まだ一部購入完了通知へ反映されていない購入分があれば、それも全件購入完了通知へ含める
    - すでに過去の一部購入完了通知でカウント済みの購入分は、全件購入完了通知では除外する
  - 対応状況:
    - [x] Flutter 側で `firstItemName` と `completedCount` を送る実装を追加
    - [x] Supabase 側に専用 RPC `notify_family_members_shopping_all_completed` を適用する
  - 補足:
    - 現在の Flutter 実装では `{firstItemName}` として「最後に完了したアイテム名」を送る
    - 旧仕様では `{count}` を「当日その人が完了した件数」として扱っていた
    - 新仕様では「未通知の購入完了分のみ」を集計するロジックへ変更が必要
    - 集約状態は `docs/sql/shopping_completion_aggregation_state.sql` の専用 table で管理する
    - 適用用 SQL: `docs/sql/notification_shopping_all_completed.sql`
- [ ] I-02 アイテム編集通知を理想仕様に一致させる
  - 目標:
    - title: `編集されたアイテムがあります`
    - body: `{actorName}さんが{itemName}を編集しました`
  - 対応状況:
    - [x] Flutter 側で編集時に専用 RPC `notify_family_members_item_edited` を呼ぶ実装を追加
    - [x] Supabase 側に専用 RPC `notify_family_members_item_edited` を適用する
- [ ] I-03 アイテム削除通知を理想仕様に一致させる
  - 目標:
    - title: `削除されたアイテムがあります`
    - body: `{actorName}さんが{itemName}を削除しました`
  - 対応状況:
    - [x] Flutter 側で削除時に専用 RPC `notify_family_members_item_deleted` を呼ぶ実装を追加
    - [x] Supabase 側に専用 RPC `notify_family_members_item_deleted` を適用する
  - 補足:
    - 適用用 SQL: `docs/sql/notification_item_edited_deleted.sql`
- [x] I-04 一部購入完了通知を理想仕様に一致させる
  - 目標:
    - title: `{actorName}さんが{count}件の買い物を完了しました`
    - body: なし
  - 仕様変更メモ:
    - 即時通知ではなく「最後の購入完了から 2 分後」に通知する
    - 同一 user が 2 分以内に追加で購入完了した場合は、最後の購入時刻を基準に待ち時間を延長する
    - 通知件数 `{count}` は「前回までの一部購入完了通知で未カウントの購入分」のみを対象にする
    - すでに別の一部購入完了通知でカウント済みの購入分は除外する
    - 2 分待ちの間に最後の未完了アイテムが購入されて全件完了になった場合は、一部購入完了通知は出さず、その未通知分を全件購入完了通知へ吸収する
  - 対応状況:
    - [x] Flutter 側で `notify_family_members_shopping_completed_batched` を呼ぶ実装へ更新
    - [x] Supabase 側に batched RPC `notify_family_members_shopping_completed_batched` を適用する
  - 補足:
    - 旧仕様では単純な 2 分窓集約だった
    - 新仕様では「未通知分の境界管理」と「全件購入完了通知への吸収」が必要
    - `notification_jobs.data.aggregate_count` だけでは足りず、どこまで通知済みかを識別する状態管理が必要
    - 集約状態は `docs/sql/shopping_completion_aggregation_state.sql` の専用 table で管理する
    - 適用用 SQL: `docs/sql/notification_shopping_completed.sql`
- [ ] I-05 リアクション通知を理想仕様に一致させる
  - 目標:
    - title: `{actorName}`
    - body: `あなたに{reactionEmoji}でリアクション`
  - 対応状況:
    - [x] Flutter 側は既存の `setNotificationReaction()` 呼び出しをそのまま利用可能
    - [x] Supabase 側で `set_notification_reaction` に通知生成処理を追加する
  - 補足:
    - 適用用 SQL: `docs/sql/notification_reaction.sql`
- [ ] I-06 チーム参加/退出/強制退出/オーナー変更/チーム削除通知を理想仕様に一致させる
  - 目標:
    - チーム系の各 title/body を理想仕様どおりに job 化する
  - 対応状況:
    - [x] Flutter 側で参加 / 退出 / 強制退出 / チーム削除の通知呼び出しを追加
    - [x] Supabase 側にチーム系専用 RPC を適用する
    - [x] `delete_my_account()` 内の owner 移譲時にオーナー変更通知を積むよう更新
  - 補足:
    - 適用用 SQL: `docs/sql/notification_team_events.sql`
    - owner 変更は `delete_my_account()` の owner 移譲時に発火する
- [ ] I-08 通知一覧の文言を push と一致させる
  - 目標:
    - `app_notifications` 側でも `title/body` を保持し、通知一覧と push の文言差をなくす
  - 対応状況:
    - [x] Flutter 側で通知一覧 UI を `title/body` 優先・`message` fallback へ更新
    - [x] Supabase 側で `app_notifications.title/body` を追加し、各通知関数が同じ文言を保存するよう更新する
  - 補足:
    - 適用用 SQL: `docs/sql/notification_list_title_body_alignment.sql`
    - 専用通知の反映用 SQL:
      - `docs/sql/item_add_push_batching.sql`
      - `docs/sql/notification_shopping_completed.sql`
      - `docs/sql/notification_item_edited_deleted.sql`
      - `docs/sql/notification_shopping_all_completed.sql`
      - `docs/sql/notification_reaction.sql`
      - `docs/sql/notification_team_events.sql`
    - 2026-03-26: 上記 SQL は Supabase へ反映済み
    - 現時点では実機再確認待ちのため、タスク自体は未完了のまま維持
- [ ] I-07 リマインド通知を理想仕様に一致させる
  - 目標:
    - 招待リマインド / 未完了24時間 / 未完了48時間 / 週末リマインドを実装する
  - 設計メモ:
    - 実装方式は Flutter 常駐ではなく Supabase 側の定期実行を前提にする
    - 毎回 `notification_jobs` を直接積み、`app_notifications` にも同じ `title/body` を保存する
    - 重複防止のため、各リマインドで `event_kind` と対象キーごとの一意判定を入れる
  - 想定する event_kind:
    - `invite_reminder_24h`
    - `shopping_remaining_24h`
    - `shopping_remaining_48h`
    - `weekend_reminder`
  - 想定実装:
    - [x] I-07a 招待リマインド 24 時間
      - 条件:
        - `families` 作成から 24 時間以上
        - その家族の `family_members` が owner 1 人のみ
      - 送信先:
        - owner のみ
      - 文言:
        - title: `チームに家族を招待しましょう`
        - body: `リンクを受け取った家族は、すぐに始められます`
    - [x] I-07b 未完了 24 時間リマインド
      - 条件:
        - 家族リストに未完了アイテムあり
        - 最終更新から 24 時間以上
      - 送信先:
        - 当該 family の全メンバー
      - 文言:
        - title: `リストに{count}点のアイテムがあります`
        - body: `確認してみませんか？`
    - [x] I-07c 未完了 48 時間リマインド
      - 条件:
        - 家族リストに未完了アイテムあり
        - 最終更新から 48 時間以上
      - 送信先:
        - 当該 family の全メンバー
      - 文言:
        - title: `リストに{count}点のアイテムが残っています`
        - body: `購入は完了していますか？`
    - [ ] I-07d 週末リマインド
      - 条件:
        - 毎週金曜 17:00 JST
        - 履歴または未完了アイテムがある family を候補にする
      - 送信先:
        - 当該 family の全メンバー
      - 文言:
        - title: `お疲れさまです。週末の買い物リストを確認しませんか？`
        - body: `履歴からワンタップで追加ができます`
  - 実装候補:
    - SQL 関数:
      - `enqueue_invite_reminder_24h()`
      - `enqueue_shopping_remaining_reminders()`
      - `enqueue_weekend_reminders()`
      - 実装ファイル: `docs/sql/notification_reminders.sql`
    - スケジューラ:
      - Supabase Scheduled Functions / pg_cron のどちらかで日次・毎時実行
      - pg_cron 用設定ファイル: `docs/sql/notification_reminder_scheduler_setup.sql`
    - 重複防止:
      - `notification_jobs.data` に `event_kind`, `family_id`, `reminder_date`, `reminder_stage` を持たせる
      - 同一 family・同一 stage・同一日では再送しない

#### 実装後に確認が必要なタスク

- [x] I-11 全件購入完了通知で title/body が理想仕様どおりになることを確認する
- [x] I-11a 全件購入完了通知で「未通知分のみ」が `{count}` に含まれることを確認する
- [x] I-11b 一部購入完了通知の 2 分待ち中に最後のアイテムが購入された場合、未通知分が全件購入完了通知へ吸収されることを確認する
- [x] I-12 アイテム編集通知で title/body が理想仕様どおりになることを確認する
- [x] I-13 アイテム削除通知で title/body が理想仕様どおりになることを確認する
- [x] I-14 一部購入完了通知で title/body が理想仕様どおりになることを確認する
  - 確認観点:
    - 最後の完了から 2 分後に 1 通だけ通知される
    - 同一 user の未通知購入分だけが `count` に反映される
    - 過去の一部購入完了通知でカウント済みの購入分が再度含まれない
- [x] I-14a 一部購入完了通知の 2 分待ち中に追加購入した場合、待機基準が最後の購入時刻へ延長されることを確認する
- [x] I-15 リアクション通知で title/body が理想仕様どおりになることを確認する
- [ ] I-16 チーム系通知で title/body が理想仕様どおりになることを確認する
  - 参加: 確認済み（title/body 正常）
  - 退出: 確認済み（title/body 正常）
  - チーム削除: 通知が 2 件重複するバグを発見 → `delete_family` RPC 内のレガシー INSERT を削除して修正。要再デプロイ後に再確認
- [x] I-20 通知一覧で push と同じ title/body が見えることを確認する
  - PowerSync sync rules の再デプロイで title/body が同期されるようになり解決
- [ ] I-17 リマインド通知が想定タイミングで重複なく届くことを確認する
- [x] I-18 Supabase 反映後に `notification_jobs.data->>'event_kind'` で新規イベントが積まれることを確認する
  - `invite_reminder_24h` / `shopping_remaining_24h` / `shopping_remaining_48h` を確認済み
- [x] I-19 `notification_jobs.status` が `pending -> sent` に遷移することを確認する
  - 手動実行で積まれた reminder jobs が `sent` になっていることを確認済み
- [x] I-21 チームメンバー向け全件完了モーダルで、名前・時刻の下に `{firstItemName}ほか{count}件を購入` 形式の文言が表示されることを確認する
- [x] I-22 チームメンバー向け全件完了モーダルで、リアクション未設定時は `いまの気持ちを伝えてみませんか？` ボックス、リアクション後はチップ表示に切り替わることを確認する

#### 本日の進捗メモ

- [x] P-01 アイテム追加通知は理想仕様と一致していることを確認
- [x] P-02 全件購入完了通知の Flutter 側 payload 対応を実装
- [x] P-03 全件購入完了通知の Supabase 専用 RPC を適用
- [x] P-04 アイテム編集通知の Flutter 側実装を追加
- [x] P-05 アイテム編集通知の Supabase 専用 RPC を適用
- [x] P-06 アイテム削除通知の Flutter 側実装を追加
- [x] P-07 アイテム削除通知の Supabase 専用 RPC を適用
- [x] P-08 I-03 の実機確認
- [x] P-09 I-04 一部購入完了通知の設計と実装
- [x] P-10 I-05 リアクション通知の Supabase 反映
- [x] P-11 I-06 チーム系通知の Supabase 反映
- [x] P-12a I-05 リアクション通知の push 文面が理想仕様と一致することを確認
- [x] P-12b I-06 チーム系通知の実イベント確認
  - 退出通知: push は正常。app_notifications が 3 行作られるバグを発見
    - 原因1: SQL の app_notifications INSERT に actor 除外がなかった → 修正済み
    - 原因2: Flutter showTopSnackBar が saveToHistory=true で重複保存 → 修正済み
  - 参加通知: 発火しないバグを発見
    - 原因: joinFamily() がローカル PowerSync DB に書き込むため、Supabase 同期前に RPC が呼ばれると `not a family member` 例外 → actor membership チェックを削除して修正済み
  - 要再テスト: SQL を Supabase に再デプロイ後、退出・参加の両方を再確認
- [x] P-21 チーム退出通知の再テスト（SQL 再デプロイ + Flutter ビルド後）
  - 確認済み: 退出者以外の全メンバーに通知が送られることを確認
- [x] P-22 チーム参加通知の再テスト（SQL 再デプロイ後）
  - 確認済み: 参加通知が正常に発火することを確認
- [x] P-23 強制退出の push 通知確認
  - 確認済み: push 通知は正常に届く
- [x] P-24 強制退出通知の通知一覧修正（SQL 再デプロイ後）
  - 問題: `app_notifications.family_id` にチーム ID が入っているため、退出済みユーザーがチームモードで見れない
  - 修正: `family_id = NULL` にして個人モードの通知一覧に表示 → SQL 修正済み、要再デプロイ
  - 確認観点:
    - 強制退出されたユーザーの個人モード通知一覧に表示されること
    - title: `チームから退出されました`、body: `{teamName} のオーナーがあなたを退出させました`
- [x] P-13 I-01 全件購入完了通知で count が当日購入件数になることを確認
- [x] P-14 I-04 一部購入完了通知が 2 分集約で count 反映されることを確認
- [x] P-15 I-02 アイテム編集通知の実機確認
- [x] P-16 I-05 リアクション通知の実機確認
- [x] P-17 I-03 アイテム削除通知の実機確認
- [x] P-18 I-07a / I-07b / I-07c の SQL 実装と Supabase 反映
- [x] P-19 I-18 / I-19 reminder jobs の生成と送信確認
- [ ] P-20 I-01 / I-04 の購入完了通知仕様変更を設計へ反映
- [x] P-21 I-04 一部購入完了通知が新仕様どおりであることを確認
- [x] P-22 I-01 全件購入完了通知で、すでに一部購入完了通知済みの件数を再カウントする不具合を修正
- [x] P-23 チームメンバー向け全件完了モーダルの文言表示を通知本文ベースへ修正
- [x] P-24 チームメンバー向け全件完了モーダルで、リアクション未設定時の案内ボックス表示を追加
- [ ] P-25 チーム削除通知の重複修正（`delete_family` RPC 再デプロイ後）
  - 問題: `notify_family_members_team_deleted` と `delete_family` の両方が `app_notifications` に INSERT していた
  - 修正: `delete_family` からレガシー通知 INSERT を削除 → `docs/sql/delete_family_rpc.sql`
  - 確認観点: チーム削除後、通知一覧・push ともに 1 件だけ表示されること

### Step 1. アイテム本体のオフライン前提を固める

#### 実装タスク

- [ ] O-00 アイテム本体のオフライン挙動を整理し、想定どおり使える状態へ揃える
  - 背景:
    - アイテム本体はローカルDB先行で、設計上はオフライン追加・更新・完了に対応している想定
    - ただし実機/シミュレーターでは `database is locked` が発生しており、ローカル書き込み競合で想定が崩れている可能性がある
    - 画像や通知など、アイテム操作に付随する周辺処理はオフライン前提が揃っていない
  - 目標:
    - テキスト中心のアイテム追加・更新・完了はオフラインでも落ちずに成立する
    - オンライン復帰後に PowerSync 同期で Supabase 側へ反映される
    - 周辺処理のオンライン依存は欠落ではなく保留扱いにできる
  - 実装タスク:
    - [ ] O-00a アイテム追加 / 更新 / 完了のオフライン受け入れ条件を明文化する
    - [x] O-00b `database is locked` の発生条件を切り分け、ローカルDB競合を解消する
      - 原因特定:
        - `PowerSync` の同期トランザクションと `TodoRepository` / `ItemsRepository` のローカル書き込みが同時実行され、SQLite の `database is locked (code 5)` が発生していた
      - 対応済み:
        - `TodoRepository` の `addItem`, `completeItem`, `updateItemName`, `uncompleteItem`
        - `ItemsRepository` の `getOrCreateItemId`, `processPendingReadings`
        - 上記に `database is locked` 限定の短時間 retry を追加
    - [ ] O-00c アイテム操作に付随するオンライン依存処理を棚卸しする

#### 実装後に確認が必要なタスク

- [ ] O-01 オフライン中にテキストのみのアイテム追加が成立し、アプリ再起動後もローカル表示が残ることを確認する
- [ ] O-02 オフライン中にアイテム完了 / 再追加が成立し、オンライン復帰後に Supabase 側へ同期されることを確認する
- [ ] O-03 オフライン中にカテゴリ付きアイテム追加を行ってもローカル状態が壊れないことを確認する
- [ ] O-06 PowerSync 同期再開後、オフライン中のアイテム変更が欠落なくサーバーへ反映されることを確認する

#### 確認手順

1. シミュレーターまたは実機でアプリを起動し、ホーム画面まで進む。
2. 起動直後の同期ログが流れている状態で、アイテムをすばやく複数回追加する。
3. 以前出ていた `SqliteException(5): database is locked` が出ず、追加したアイテムがローカル一覧に残ることを確認する。
4. 追加したアイテムを完了し、履歴から再追加して、完了 / 再追加でも同様にロック例外が出ないことを確認する。
5. 通信を一度切った状態でテキストのみのアイテムを追加し、アプリ再起動後もローカル表示が残ることを確認する。
6. 通信を戻し、PowerSync 同期後に追加・完了した内容が Supabase 側にも反映されることを確認する。

### Step 2. アイテム付随処理のオフライン方針を揃える

#### 実装タスク

- [x] O-00d 画像アップロードのオフライン時方針を決める
  - 候補:
    - オフライン時は画像なしで保存し、画像だけ保留
    - ローカルパス退避 + 後送信
    - 画像付き追加自体をオフラインでは不可にする
  - 完了条件:
    - UX とデータ整合性の方針が決まり、必要なら別タスクへ分割されていること
  - 対応済み:
    - 当面は「オフライン時は画像なしで保存し、アイテム本体だけ通す」方針を採用
    - 画像アップロード失敗時は追加 / 編集処理を継続し、UI で「画像は保存せず本体だけ保存した」旨を表示
    - 画像の後送信は未実装のため、必要なら別タスクで queue 化を検討する
- [x] O-00e ふりがな pending queue の再実行タイミングを整理する
  - 現状:
    - `pending_hiragana_update_ids` はあるが、運用上いつ掃除するかが明確でない
  - 完了条件:
    - アプリ起動時 / オンライン復帰時などの再実行タイミングが決まっていること
  - 対応済み:
    - ホーム初期化時に `processPendingReadings()` を実行
    - サインイン時と `AppLifecycleState.resumed` でも `processPendingReadings()` を実行

#### 実装後に確認が必要なタスク

- [ ] O-04 オフライン中の画像付き追加の挙動が、定義した方針どおりになることを確認する
- [ ] O-05 オフライン中に漢字名アイテムを追加した場合、ふりがな pending queue に積まれて後から更新されることを確認する

### Step 3. 通知のオフラインキュー化を実装する

#### 実装タスク

- [x] N-00 オフライン時の通知要求をローカルキューへ退避し、オンライン復帰後に同期と通知送信を再開できるようにする
  - 背景:
    - 現状は `NotificationsRepository` から Supabase RPC を即時実行している
    - オフラインや DNS 解決失敗時は `SocketException / ClientException` が発生しうる
    - その場で通知要求が失われると、アイテム追加は成功しても家族通知だけ欠落する
  - 目標:
    - オフライン時は通知要求をローカルへ保存する
    - オンライン復帰後に未送信要求を順次 Supabase RPC へ流す
    - 通知要求の再送はアプリクラッシュや再起動をまたいでも継続できる
  - 実装タスク:
    - [x] N-00a 通知キューの保存先を定義する
    - [x] N-00b `NotificationsRepository` を即時送信 + 失敗時キュー退避の動作へ変更する
    - [x] N-00c オンライン復帰時のキュー flush トリガーを実装する
    - [x] N-00d 再送時の重複送信防止ルールを決める
    - [x] N-00e 失敗ログと運用観点を追加する
  - 対応メモ:
    - `SharedPreferences` に `queued_family_notification_requests_v1` として通知要求を保存
    - 一時的なネットワーク失敗 (`SocketException` / `ClientException` / `TimeoutException`) のときだけ queue 退避
    - `PostgrestException` は server-side 失敗として従来どおりログ出しし、無条件には queue しない
    - サインイン時と `AppLifecycleState.resumed` で queue flush を自動実行
    - 同一 RPC + familyId + params の重複 enqueue は 1 件にまとめる

#### 実装後に確認が必要なタスク

- [ ] N-06 オフライン中にアイテム追加してもアプリが落ちず、通知要求が queue に保存されることを確認する
- [ ] N-07 オンライン復帰後、保存済み queue が flush されて `notification_jobs` に反映されることを確認する
- [ ] N-08 オフライン中に複数件追加した場合でも、再送時に重複や欠落が起きないことを確認する
- [ ] N-09 アプリ再起動後も queue が残り、オンライン復帰で再送されることを確認する

### Step 4. 通知運用の最終調整

#### 実装タスク

- [x] N-01a 文言変更だけで対応できる通知を確認する
  - 対応済み:
    - アイテム追加 push の title/body は `docs/sql/item_add_push_batching.sql` 上ですでに理想案と一致していることを確認
    - UI 用の案内/失敗メッセージ 3 件を `saveToHistory: false` に変更し、家族向け push / 通知履歴保存の対象外に整理
  - 保留:
    - 全件購入完了通知は `{firstItemName}` / `{count}` を本文に含める追加データ整形が必要
    - リアクション通知は push イベント化が未整理
- [ ] N-01 `partial_failure` を独立 status に昇格するか運用判断を確定する
  - 現状:
    - `notification_jobs.delivery_summary` と `notification_job_delivery_logs` で全成功 / 一部成功 / 全失敗は追跡できる
    - 一部成功は summary 上で判別できるが、job の status としては独立扱いしていない
  - 判断したいこと:
    - 運用監視で `partial_failure` を `failed` と分けて扱う必要があるか
    - 再送条件やアラート条件を `partial_failure` 専用に持つか
  - 完了条件:
    - status を増やす / 増やさないの方針が決まり、必要なら schema / worker / 監視SQLまで反映されていること

#### 実装後に確認が必要なタスク

- [ ] N-02 アイテム追加で `notification_jobs` に `pending` が増えることを定期確認する
- [ ] N-03 worker 実行で `pending -> sent/failed` に遷移することを確認する
- [ ] N-04 失敗時に `last_error` に理由が残ることを確認する
- [ ] N-05 実端末で通知が届くことを確認する

### Step 5. 通知設定画面を機能させる

#### 現状の問題

- 通知設定画面は MVP では 5 種類の個別トグルを提供する
- 個別トグルは `device_tokens.notification_preferences` と同期し、`send-push` worker が `event_kind` に応じてフィルタする
- マスタートグル OFF 時は `device_tokens` から当該端末トークンを削除し、push を完全停止する
- 通知一覧はトグル状態に関係なく `app_notifications` を表示する

#### トグルと通知種別の対応表

| トグル | SharedPreferences キー | 対応する通知 |
|--------|----------------------|-------------|
| リストの更新 (追加・編集・削除) | `notify_list_updates` | `item_added` / `item_edited` / `item_deleted` |
| 買い物完了 | `notify_shopping_complete` | `shopping_completed` / `shopping_all_completed` |
| ひとこと掲示板の更新 | `notify_board_updates` | `board_updated` |
| スタンプでのリアクション | `notify_reactions` | `reaction` |
| リマインド | `notify_reminders` | `invite_reminder_24h` / `shopping_remaining_24h` / `shopping_remaining_48h` / `weekend_reminder` |

#### 実装方針の候補

- **A. サーバーサイドフィルタ（推奨）**
  - `device_tokens` テーブルに通知設定カラムを追加し、Flutter からトグル変更時に同期する
  - `send-push` worker が job 処理時に `device_tokens` の設定を参照し、該当カテゴリ OFF なら skip する
  - メリット: バックグラウンド push も含めて確実に止まる。通信量が減る
  - デメリット: DB スキーマ変更 + worker 改修が必要
- **B. クライアントサイドフィルタ**
  - `notification_jobs.data.event_kind` をそのまま push の `data` に含めて送信する
  - Flutter のフォアグラウンドハンドラで `event_kind` と個別トグルを突き合わせて表示を抑制する
  - メリット: サーバー変更不要
  - デメリット: バックグラウンド push は止められない（OS が直接表示するため）
- **C. A + B のハイブリッド**
  - サーバーで基本フィルタ、フォアグラウンドでも二重チェック

#### 方針決定

- **方針 A（サーバーサイドフィルタ）** を採用
- push 通知だけ止める。通知一覧（`app_notifications`）はトグルに関係なく表示を維持する

#### 実装タスク

- [x] NS-00 通知設定の実装方針を確定する → 方針 A
- [x] NS-01 `notification_jobs.data.event_kind` が push の `data` payload に含まれることを確認する
  - 専用 RPC は全て `event_kind` あり
  - `item_add_push_batching.sql` に `event_kind: 'item_added'` を追加
  - 汎用フォールバック `notify_family_members` は `event_kind` なし → 専用 RPC 移行済みのため低優先
- [x] NS-02 `device_tokens` テーブルに `notification_preferences jsonb` カラムを追加する
  - 適用 SQL: `docs/sql/device_tokens_notification_preferences.sql`
- [x] NS-03 Flutter のトグル変更時に `device_tokens.notification_preferences` を Supabase へ同期する
  - `DeviceTokensRepository.syncNotificationPreferences()` を追加
  - `_setDetailEnabled()` から呼び出し
- [x] NS-04 `send-push` worker で `notification_preferences` を参照し、該当カテゴリ OFF のトークンを skip する
  - `EVENT_KIND_TO_PREF_KEY` マッピングでフィルタ
  - 全 skip 時は `sent` 扱い（ユーザー設定による正常動作）
- [x] NS-05 通知設定画面の初期表示でサーバー側 `notification_preferences` を読み、ローカル表示と同期する
- [x] NS-05a トークン登録時にローカルの個別トグル状態も `device_tokens` に同時保存する
- [x] NS-06 マスタートグル OFF 時に `device_tokens` からトークンを削除して push を完全停止する
  - `_setEnabled(false)` で `deleteCurrentDeviceToken()` を呼び出し
- [x] NS-07 ひとこと掲示板更新を専用 `event_kind=board_updated` で push フィルタ対象にする

#### MVP判断

- [x] NS-MVP-01 運営からのお知らせ機能は MVP 対象外とし、通知一覧のタブ機能は削除する
- [x] NS-MVP-02 通知設定画面の `運営からのお知らせ` トグルは削除する

#### 実装後に確認が必要なタスク

- [ ] NS-08 個別トグル OFF の通知種別で push が届かないことを確認する
- [ ] NS-09 個別トグル ON の通知種別は引き続き正常に push が届くことを確認する
- [ ] NS-10 マスタートグル OFF で全 push が停止し、ON で復帰することを確認する
- [ ] NS-11 複数端末がある場合、端末ごとに設定が独立して機能することを確認する

## 自動実行

- scheduler 用 SQL は `docs/sql/push_worker_scheduler_setup.sql`
- vault 登録用 SQL は `docs/sql/push_worker_vault_setup.sql`
- 本番では cron から 1 分おきに `send-push` を呼ぶ

## 関連資料

- 状態メモ: `docs/push-worker-status.md`
- 完了済み通知タスク: `docs/COMPLETED_TASKS.md`
- 監視SQL: `docs/sql/notification_jobs_monitoring.sql`
