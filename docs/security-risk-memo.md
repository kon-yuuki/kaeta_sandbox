# セキュリティ懸念メモ（後対応）

更新日: 2026-02-14  
対象: 招待機能・通知/外部API周辺

## 優先度 High

### 1. 招待参加の検証をクライアント実装に依存している
- 対象: `lib/data/repositories/families_repository.dart` の `joinFamily`
- 現状:
  - クライアントから `familyId` を指定して `family_members` 追加・`invitations` 削除を実行
  - DB/RPC 側での厳格検証（有効期限、invite-family整合、使用済み判定）をコード上確認できていない
- リスク:
  - サーバー側制約が弱い場合、不正参加の余地
- 対応方針:
  - `join_family_by_invite(invite_id)` のRPC化
  - クライアントは `inviteId` のみ渡す
  - 検証はDB関数内で完結

## 優先度 Medium

### 2. 招待リンク流出時の情報露出
- 対象: `fetchInvitationDetails(inviteId)`
- 現状:
  - 未ログインでも `family名` と `inviter表示名` が取得可能な実装
- リスク:
  - URL流出時に第三者が情報閲覧可能
- 対応方針:
  - 返却情報を最小化（例: family名のみに限定）
  - レート制限、監査ログ、期限短縮

### 3. 外部APIの識別子がクライアント埋め込み
- 対象: `lib/data/repositories/items_repository.dart` の Yahoo API `clientId`
- リスク:
  - 逆コンパイルで抽出され、クォータ消費・濫用される可能性
- 対応方針:
  - サーバープロキシ化
  - クライアントからは内部APIのみ呼び出す

## 優先度 Low

### 4. SharedPreferences の利用
- 対象: カテゴリ並び順保存（`category_order_provider.dart`）
- 現状:
  - 端末ローカル保存、改ざん耐性はない
- 判断:
  - 機微データではないため、現時点では許容

## 未確認事項（要サーバー確認）
- Supabase の RLS / SQL policy / RPC実装の最終確認
  - `family_members`
  - `invitations`
  - `notify_family_members`
  - `set_notification_reaction`

## 対応優先順（推奨）
1. 招待参加フローのRPC一本化（High）
2. 招待詳細APIの露出最小化（Medium）
3. Yahoo APIのサーバー経由化（Medium）

