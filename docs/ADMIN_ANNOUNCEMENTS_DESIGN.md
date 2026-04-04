# 運営からのお知らせ 設計メモ

更新日: 2026-03-30

## ステータス

- MVP スコープ外
- 通知一覧のタブ機能は削除済み
- 通知設定画面の `運営からのお知らせ` トグルも削除済み
- この資料は将来再開する場合の保留メモとして残す
## 概要

将来、運営告知をアプリ内で扱う場合の設計メモ。MVP では実装しない。

## 2026-03-30 時点の現状

- `NotificationsScreen` は単一の通知一覧画面
- 通知設定画面に `notify_admin_announcements` トグルは存在しない
- `send-push` に `admin_announcement` 用のマッピングは未実装

## 方式: 専用テーブル + PowerSync broadcast 同期

### 選定理由

| 方式 | 概要 | 判定 |
|------|------|------|
| **A. 専用テーブル broadcast** | `admin_announcements` を全ユーザーに同期 | 採用 |
| B. `app_notifications` 相乗り | ユーザー数分の行を INSERT | 行爆発で非現実的 |
| C. 外部 CMS (Notion 等) | API で都度取得 | オフライン不可 |

### 配信フロー

```
運営: Supabase Dashboard で admin_announcements に INSERT
  ↓
PowerSync: sync rule で全認証ユーザーに自動同期
  ↓
Flutter: 将来の専用 UI にリアルタイム表示
  ↓
ユーザー: タップ → url_launcher で外部リンクを開く
```

### Supabase テーブル設計 (案)

```sql
create table public.admin_announcements (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  body         text,
  url          text,                          -- タップ時に開く外部リンク
  published_at timestamptz,                   -- NULL = 下書き、非 NULL = 公開
  created_at   timestamptz not null default now()
);

-- RLS: 認証済みユーザーは SELECT のみ
alter table public.admin_announcements enable row level security;
create policy "Authenticated users can read published announcements"
  on public.admin_announcements for select
  to authenticated
  using (published_at is not null);
```

### PowerSync sync rule (案)

```yaml
- name: admin_announcements
  table: admin_announcements
  filter: "published_at IS NOT NULL"
  # user_id フィルタなし → 全ユーザーに broadcast
```

### Drift / PowerSync スキーマ (案)

```dart
// schema.dart - PowerSync
ps.Table('admin_announcements', [
  ps.Column.text('title'),
  ps.Column.text('body'),
  ps.Column.text('url'),
  ps.Column.text('published_at'),
  ps.Column.text('created_at'),
]),

// schema.dart - Drift
class AdminAnnouncements extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  TextColumn get url => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 既読管理 (案)

- SharedPreferences に告知 ID の Set を保存（端末ローカル）
- 未読バッジ = 全告知数 - 既読 ID 数

### Push 通知 (任意・後回し可)

- 告知 INSERT 時に Supabase Trigger で `notification_jobs` を全ユーザー分作成
- 将来トグルを復活させる場合は `event_kind: 'admin_announcement'` のフィルタを再設計する
- 全ユーザーへの一斉配信は負荷が大きいため、初期は push なし（PowerSync 同期のみ）でも可

## 将来再開する場合の実装タスク

- [ ] AN-01 Supabase に `admin_announcements` テーブルを作成
- [ ] AN-02 PowerSync sync rule に `admin_announcements` を追加
- [ ] AN-03 Drift / PowerSync スキーマに `admin_announcements` を追加 + コード生成
- [ ] AN-04 `AdminAnnouncementsRepository` を作成（watch / 既読管理）
- [ ] AN-05 告知 UI の実装（リスト表示 + タップで外部リンク）
- [ ] AN-06 未読バッジ表示
- [ ] AN-07 (任意) Push 通知の実装

## 未決事項

- [ ] テーブル設計の最終確定
- [ ] PowerSync sync rule の書き方確認（broadcast パターン）
- [ ] Push 通知を初期リリースに含めるか
- [ ] 告知の保持期間（無期限 or 自動削除）
- [ ] 既読管理を端末ローカル (SharedPreferences) で十分か
