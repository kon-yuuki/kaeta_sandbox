-- device_tokens に通知設定カラムを追加する
-- 各トグルの ON/OFF を JSON で保持し、send-push worker がフィルタに使用する
--
-- 例: {
--   "notify_list_updates": true,
--   "notify_shopping_complete": true,
--   "notify_board_updates": true,
--   "notify_reactions": true,
--   "notify_reminders": true,
-- }
--
-- デフォルトは空 JSON（= 全 ON 扱い）。キーが存在しない場合は ON とみなす。

alter table public.device_tokens
  add column if not exists notification_preferences jsonb not null default '{}'::jsonb;

comment on column public.device_tokens.notification_preferences is
  'Per-device notification toggle preferences. Missing keys are treated as enabled.';
