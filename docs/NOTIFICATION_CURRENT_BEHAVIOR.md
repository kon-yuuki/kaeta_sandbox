# NOTIFICATION CURRENT BEHAVIOR

更新日: 2026-03-29

## 目的

- 現状の push 通知とスナックバー通知の発火条件を一覧で確認できるようにする
- どの通知が家族向け push に繋がるか、どの通知が UI 表示だけかを切り分ける

## 仕組みの前提

- `showTopSnackBar()` はデフォルトで `saveToHistory: true`
- `showTopSnackBar()` に `familyId` を渡すと、`publishNotification()` 経由で `notify_family_members` RPC が呼ばれる
- そのため、`familyId` あり + `saveToHistory: true` のスナックバーは、通知履歴保存だけでなく家族向け push 配信に繋がる
- `familyId` が `null` または空文字の場合は、ローカルの `app_notifications` への保存のみ
- `saveToHistory: false` の場合は、画面上のスナックバー表示のみで通知履歴保存も push 配信も行わない
- FCM / APNs を受信したときは、アプリがフォアグラウンドなら `NotificationService.showNotification()` で OS 通知を表示する

## Push 通知が発生する条件

### 1. アイテム追加

- 条件:
  - 家族利用中にアイテムを追加したとき
- 文面:
  - `「{itemName}」をリストに追加しました！`
- 経路:
  - `HomeViewModel.addTodo()`
  - `HomeViewModel.addFromHistory()`
  - `NotificationsRepository.notifyShoppingAdded()`
  - `notify_family_members_item_added_batched`
  - fallback: `notify_family_members`

### 2. アイテム完了

- 条件:
  - 家族利用中にアイテムを完了したとき
- 文面:
  - `「{itemName}」を完了しました！`
- 経路:
  - `HomeViewModel.completeTodo()`
  - `NotificationsRepository.notifyShoppingCompleted()`
  - `notify_family_members`

### 3. 全アイテム完了

- 条件:
  - 家族利用中に最後の未完了アイテムを完了し、未完了件数が 0 件になったとき
- 文面:
  - `買い物リストのアイテムがすべて購入されました！`
- 経路:
  - `HomeViewModel.completeTodo()`
  - `NotificationsRepository.notifyShoppingAllCompleted()`
  - `notify_family_members`

### 4. ひとこと掲示板更新

- 条件:
  - 家族利用中に掲示板のひとことを更新したとき
- 文面:
  - `{actorName}さんがひとことを更新: {本文先頭20文字}...`
  - 20 文字以内なら省略記号なし
- 経路:
  - `board_detail_screen.dart`
  - `NotificationsRepository.notifyBoardUpdated()`
  - `notify_family_members`

### 5. familyId 付きスナックバー保存

- 条件:
  - `showTopSnackBar(... familyId: あり, saveToHistory: true)` を呼んだとき
- 文面:
  - スナックバーに渡した文言そのもの
- 経路:
  - `showTopSnackBar()`
  - `NotificationsRepository.publishNotification()`
  - `notify_family_members`

## 現状、家族向け push に繋がるスナックバー

### 1. アイテム・履歴関連

- `「{item}」をリストに追加しました`
- `「{item}」を元に戻しました`
- `「{item}」を編集しました`
- `追加に失敗しました。設定を確認してください`
- `「{item}」を削除しました`
- `元に戻せませんでした`

### 2. カテゴリ関連

- `カテゴリ名を「{newName}」に変更しました`
- `カテゴリ名を元に戻しました`
- `同じ名前のカテゴリは変更できません`
- `カテゴリ「{name}」を追加しました`
- `現在のプランではカテゴリ{limit}件までです`
- `同じ名前のカテゴリは追加できません`

### 3. 一部の案内メッセージ

- `プレミアムプラン詳細は準備中です`
  - `familyId` 付きで呼ばれている箇所がある

## スナックバー表示だけの通知

### 1. saveToHistory: false を明示しているもの

- 招待導線のメッセージ
- 既存アカウントログイン成功メッセージ
- `category_edit_sheet.dart` 内の action 付きスナックバー

### 2. familyId なしで保存されるもの

- 設定 / プロフィール / チーム管理系の多くのメッセージ
- 例:
  - `チーム名を更新しました`
  - `招待リンクの作成に失敗しました`
  - `チームを削除しました`
  - `メンバーを退出させました`
  - `チームから退出しました`
  - `連携しました`
  - `連携を解除しました`
  - `名前を「...」に保存しました`
  - `アイコンを変更しました`
  - `購入情報を復元しました`

## Push 受信時の画面表示

### フォアグラウンド受信

- 条件:
  - Firebase Messaging `onMessage` を受信
  - payload に `title` または `body` がある
- 表示:
  - `NotificationService.showNotification()` で OS 通知を表示
  - title が空なら `お知らせ`

### バックグラウンド / 終了状態からの復帰

- `onMessageOpenedApp`
  - 開封ログを出すのみ
- `getInitialMessage`
  - 終了状態から開いた場合のログを出すのみ
- 現状は通知タップ時の専用画面遷移は未整理

## 注意点

- 現状の `showTopSnackBar()` は UI 表示用のつもりで呼んでも、`familyId` と `saveToHistory: true` の組み合わせだと家族向け push に繋がる
- そのため、UI フィードバックのつもりのメッセージが意図せず家族通知になっている可能性がある
- 通知仕様の整理時は、少なくとも以下を切り分けて見直す必要がある
  - 本当に家族へ送るべきイベント
  - ローカル履歴だけ残したいイベント
  - 画面表示だけで十分なイベント

## 理想案: ユーザーアクション通知

以下は、ユーザーから共有された理想仕様メモをそのまま整理したもの。

| 通知タイトル | 通知本文 | トリガー | タイミング |
| --- | --- | --- | --- |
| リストにアイテムが追加されました | `{actorName}さんが{count}個のアイテムを追加しました` | アイテム追加 | 最後の追加から2分後 |
| 編集されたアイテムがあります | `{actorName}さんが{itemName}を編集しました` | アイテム編集 | 即時 |
| 削除されたアイテムがあります | `{actorName}さんが{itemName}を削除しました` | アイテム削除 | 即時 |
| `{actorName}さんがすべての買い物を完了しました` | `{firstItemName}ほか{count}件を購入。アプリからスタンプを送れます` | 購入完了 | 即時 |
| `{actorName}さんが{count}件の買い物を完了しました` | - | 購入完了（一部） | 最後の購入完了から2分後 |
| `{actorName}` | あなたに{reactionEmoji}でリアクション | スタンプ送信 | 即時 |
| `{actorName}さんがチームに参加しました` | お買い物完了時にはリアクションができます | チーム参加 | 即時 |
| `{actorName}さんがチームを退出しました` | - | チーム退出 | 即時 |
| `{newOwnerName}さんが新しいオーナーになりました` | - | オーナー変更 | 即時 |
| オーナーがチームを削除しました | - | チーム削除 | 即時 |
| チームから退出されました | `{teamName}` のオーナーがあなたを退出させました | 強制退出 | 即時 |

### 補足

- `-` は本文なし想定
- `{actorName}`, `{newOwnerName}`, `{firstItemName}`, `{itemName}`, `{teamName}`, `{count}`, `{reactionEmoji}` は可変値
- アイテム追加だけは即時ではなく、最後の追加から 2 分後にまとめて送る想定
- 一部購入完了通知は、最後の購入完了から 2 分後に未通知分だけまとめて送る想定
- 全件購入完了通知は即時送信し、2 分待ち中で未通知の一部購入分があればそれも吸収する想定

## 理想案: リマインド通知

以下は、ユーザーから共有された理想仕様メモをそのまま整理したもの。

| 通知タイトル | 通知本文 | トリガー | タイミング |
| --- | --- | --- | --- |
| チームに家族を招待しましょう | リンクを受け取った家族は、すぐに始められます | 招待せず24時間経過 | 24時間後 |
| リストに{count}点のアイテムがあります | 確認してみませんか？ | リスト未完了24時間経過 | 24時間後 |
| リストに{count}点のアイテムが残っています | 購入は完了していますか？ | リスト未完了48時間経過 | 48時間後 |
| お疲れさまです。週末の買い物リストを確認しませんか？ | 履歴からワンタップで追加ができます | 週末リマインド | 金曜17:00 |

### 補足

- `{count}` は未完了アイテム数のプレースホルダー
- 招待リマインドは「チーム作成後、24時間経っても招待していない」ケースを想定
- リスト未完了リマインドは、未完了アイテムが残ったまま 24 時間 / 48 時間経過したケースを想定
- 週末リマインドは定期通知想定

## 現状との差分メモ

- 現状は「アイテム追加」「購入完了」「全件購入完了」「掲示板更新」は一部実装済み
- ただし文面は理想案と一致していない
- アイテム編集、アイテム削除、スタンプ送信、チーム参加、チーム退出、オーナー変更、チーム削除、強制退出は、理想案どおりの push 通知仕様としては未整理
- 現状の `showTopSnackBar()` 起点の通知には、理想案にない UI メッセージが混在している

## 実装整理

### 1. 通知内容の変更が中心で済みそうなもの

以下は、現状すでに近いトリガーや通知経路があり、主に文言整理や payload 整形で寄せられそうなもの。

| 理想通知 | 現状 | 実装観点 | 状態 |
| --- | --- | --- | --- |
| リストにアイテムが追加されました | `notifyShoppingAdded()` があり、2分集約の batched RPC もある | `docs/sql/item_add_push_batching.sql` の push title/body は理想案と一致 | 完了済み |
| `{actorName}さんがすべての買い物を完了しました` | `notifyShoppingAllCompleted()` がある | Flutter 側で `firstItemName` を送り、Supabase 側で当日完了件数を集計する形に調整済み | 確認待ち |
| `{actorName}` / あなたに{reactionEmoji}でリアクション | `set_notification_reaction` と reaction UI はある | Flutter 側の呼び出しは既存のまま利用できる。Supabase 側で通知生成を追加済み | 確認待ち |

### 2. 通知処理自体の追加実装が必要なもの

以下は、現状コード上で理想通知に対応する専用 push 処理が見当たらず、新しいイベント発火や配信経路の追加が必要なもの。

| 理想通知 | 現状 | 必要そうな追加実装 |
| --- | --- | --- |
| 編集されたアイテムがあります | 編集後のスナックバーはあるが、専用 push はない | アイテム編集時の通知イベント追加 |
| 削除されたアイテムがあります | 削除後のスナックバーはあるが、専用 push はない | アイテム削除時の通知イベント追加 |
| `{actorName}さんが{count}件の買い物を完了しました` | 部分完了専用の push はない。現状は個別 item 完了通知 | 一部完了用の専用通知設計が必要 |
| `{actorName}さんがチームに参加しました` | 参加完了時の専用 push は見当たらない | チーム参加イベント通知追加 |
| `{actorName}さんがチームを退出しました` | 退出後のローカルスナックバーはあるが、専用 push は見当たらない | チーム退出イベント通知追加 |
| `{newOwnerName}さんが新しいオーナーになりました` | `delete_my_account()` の owner 移譲内で発火する形に更新済み | Supabase 側で owner 変更通知生成を追加済み | 確認待ち |
| オーナーがチームを削除しました | 削除後のローカルスナックバーはあるが、他メンバー向け push は未確認 | チーム削除イベント通知追加 |
| チームから退出されました | 強制退出後の本人向け push は未確認 | 強制退出イベント通知追加 |

### 3. リマインド通知で追加実装が必要なもの

リマインド通知は、現状コード上で定期発火や遅延発火の仕組みが見当たらないため、すべて新規実装前提。

| 理想通知 | 現状 | 必要そうな追加実装 |
| --- | --- | --- |
| チームに家族を招待しましょう | 未実装 | 招待未実施 24 時間判定 + スケジューリング |
| リストに{count}点のアイテムがあります | 未実装 | 未完了リスト 24 時間判定 + スケジューリング |
| リストに{count}点のアイテムが残っています | 未実装 | 未完了リスト 48 時間判定 + スケジューリング |
| お疲れさまです。週末の買い物リストを確認しませんか？ | 未実装 | 毎週金曜 17:00 の定期スケジュール実装 |

### 4. 注意点

- 現状の `showTopSnackBar()` 起点の通知は、理想通知のイベント設計とは別に UI 文言がそのまま配信されている箇所がある
- そのため、単純な文言変更だけではなく「どのイベントを push 対象にするか」の切り分けが必要
- 特に以下は、先に通知起点を整理したほうが安全
  - アイテム編集
  - アイテム削除
  - チーム参加 / 退出 / 強制退出
  - オーナー変更
  - リアクション通知

## 文言修正メモ

### 修正済み

- アイテム追加 push 文言
  - `docs/sql/item_add_push_batching.sql` の push title は `リストにアイテムが追加されました`
  - push body は `{actorName}さんが{count}個のアイテムを追加しました` 相当
- 全件購入完了通知
  - Flutter 側で `notify_family_members_shopping_all_completed` へ `firstItemName` と `completedCount` を渡す実装を追加
  - Supabase 側の専用 RPC が未適用でも、既存 `notify_family_members` へ fallback して通知欠落は起きない
  - 現在の `{firstItemName}` は「最後に完了したアイテム名」を送る実装
  - 理想案と一致していたため、追加修正なしで完了扱い
- UI メッセージの通知履歴保存除外
  - 以下は `familyId` 付きでも `saveToHistory: false` に変更し、家族向け push / 通知履歴保存の対象外にした
  - `プレミアムプラン詳細は準備中です`
  - `追加に失敗しました。設定を確認してください`
  - `元に戻せませんでした`
  - 対象ファイル:
    - `lib/pages/home/widgets/history_add_view.dart`
    - `lib/pages/home/widgets/todo_add_sheet.dart`
    - `lib/pages/home/widgets/todo_list_view.dart`

### 保留

- 全件購入完了通知
  - 理想案の本文に `{firstItemName}` / `{count}` が必要で、文言変更だけでは足りない
- リアクション通知
  - 文言以前に、push 通知イベントとしての送信経路整理が必要

## Supabase 反映の考え方

- Flutter コードやドキュメントの確認だけで済む作業もある
- 一方で、以下に触る変更は Supabase 側の反映が必要になる可能性が高い
  - RPC / SQL 関数の文言変更
  - `notification_jobs` に積む `title` / `body` / `data` の変更
  - リマインド通知の cron / scheduler 追加
  - Edge Function `send-push` の payload 変更
- repo 内の SQL ファイルを修正しただけでは、本番や検証環境には自動反映されない
- Supabase 管理画面、SQL Editor、または migration 適用が必要な段階になったら、その時点でこちらから明示して伝える
- 逆に、まだローカル修正や設計整理の段階なら、不要な Supabase 作業は依頼しない

## 主な参照元

- `lib/data/repositories/notifications_repository.dart`
- `lib/core/snackbar_helper.dart`
- `lib/data/services/notification_service.dart`
- `lib/pages/home/view_models/home_view_model.dart`
- `lib/pages/home/widgets/todo_add_sheet.dart`
- `lib/pages/home/widgets/todo_list_view.dart`
- `lib/pages/home/widgets/history_add_view.dart`
- `lib/pages/home/widgets/board_detail_screen.dart`
