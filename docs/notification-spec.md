# 通知仕様（現状）

更新日: 2026-03-15

## 1. 通知一覧の基本仕様
| 項目 | 仕様 |
|---|---|
| 画面タブ | `通知` / `お知らせ` |
| データ表示 | 実データは `通知` タブ。`お知らせ` は現在空表示 |
| 既読化タイミング | 通知画面を開いた時点で表示対象通知を既読化 |
| 削除 | 1件スワイプ削除、メニューから全削除 |

## 2. 通知タイプ
| type | 名称 | 保持期間 | 主な発火元 |
|---|---|---|---|
| 0 | 通常通知 (`normal`) | 30日 | `showTopSnackBar(..., saveToHistory: true)` 系 |
| 1 | 買い物完了 (`shoppingComplete`) | 7日 | ホームの購入完了操作 |

## 3. 配信スコープ
| 利用モード | 配信先 |
|---|---|
| 個人利用（familyIdなし） | 自分のみ（ローカル通知追加） |
| 家族利用（familyIdあり） | `notify_family_members` RPCで家族メンバーへ配信 |

## 4. 自分の操作通知の扱い（今回変更）
| 項目 | 仕様 |
|---|---|
| 方針 | 自分が実行者の家族通知は自分には表示しない |
| 判定条件 | `familyId` あり かつ `actor_user_id == currentUserId` を通知一覧対象から除外 |
| 影響範囲 | 通知一覧表示 / 通知件数（未読数）/ 既読化対象 |
| 備考 | サーバー側で行レコードが作成されても、クライアント表示対象から除外される |

## 5. リアクション（スタンプ）
| 項目 | 仕様 |
|---|---|
| 対象通知 | `shoppingComplete` のみ |
| 利用条件 | 家族通知 + `event_id` あり + 自分が実行者ではない |
| 反映方法 | `set_notification_reaction` RPC |
| 一覧表示 | 絵文字ごとの集計バッジを表示、タップでメンバー一覧 |

## 6. 実装参照
- `lib/pages/notifications/notifications_screen.dart`
- `lib/data/repositories/notifications_repository.dart`
- `lib/data/providers/notifications_provider.dart`
- `supabase/functions/send-push/index.ts`

## 7. サーバー配信の現状
| 項目 | 仕様 |
|---|---|
| Producer | `public.notify_family_members` |
| Outbox | `public.notification_jobs` |
| 配送ログ | `public.notification_job_delivery_logs` |
| Consumer | `supabase/functions/send-push` |
| Queue投入条件 | 家族利用（`familyId` あり）の通知 |
| Worker結果 | 受信者ユーザーの全有効トークン送信成功時のみ `sent`。1件でも失敗があれば `failed` |
| 可観測性 | `notification_jobs.delivery_summary` と `notification_job_delivery_logs` で全成功 / 一部成功 / 全失敗を追跡 |

## 8. 現在 push 対象の操作
| 操作 | 実装経路 | push |
|---|---|---|
| アイテム追加 | `notifyShoppingAdded` | 送る |
| アイテム完了 | `notifyShoppingCompleted` | 送る |
| 全件完了 | `notifyShoppingAllCompleted` | 送る |
| ひとこと掲示板更新 | `notifyBoardUpdated` | 送る |
| `showTopSnackBar(..., saveToHistory: true, familyId: あり)` を使う操作 | `publishNotification -> notify_family_members` | 送る |

補足:
- 追加 / 完了系は既存の専用通知経路を使う
- 掲示板更新は `〇〇さんがひとことを更新: 本文先頭20文字` の文面で送る
- 家族モードの追加 / 完了 UI は `saveToHistory: false` にしてあり、重複送信を避けている
- 標準の `ScaffoldMessenger.showSnackBar(...)` は push 対象外
- `showTopSnackBar(..., saveToHistory: false)` も push 対象外
## 9. 運用メモ
- `pg_net` による DB からの直接 HTTP 呼び出しは本番経路から外した
- 調査ログは `docs/push-worker-status.md` に記録
- 一部端末にしか届かなかったケースも `notification_job_delivery_logs.outcome = 'partial_failure'` で判別できる
