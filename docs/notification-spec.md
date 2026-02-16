# 通知仕様（現状）

更新日: 2026-02-14

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

