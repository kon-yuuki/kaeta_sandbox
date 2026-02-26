# 招待機能 通常フロー整理（特殊ケース除外）

最終更新日: 2026-02-26
対象: 通常の招待参加フローのみ（P6/P7/S8 は除外）

## 0. 用語定義（この資料内）
- Universal Link直起動:
  - `https://kaeta-jointeam.com/invite/<inviteId>` をタップした時に、ブラウザ画面を経由せずKaetaアプリが直接開く挙動。
- Webフォールバック:
  - 上記リンクタップ時に一度ブラウザページが開き、そこで `アプリで開く` ボタンを押してKaetaへ遷移する挙動。
  - ブラウザページには以下が表示される:
    - タイトル: `招待リンクを開きました`
    - ボタン: `アプリで開く`
    - ボタン: `アプリをインストール（TestFlight）`
    - 補助文: 開けない場合の `kaeta://invite/<inviteId>` 案内

## 1. 対象パターン一覧
| パターンID | 前提（受信者） | 正解フロー（期待） | 現状（最新） | 判定 |
|---|---|---|---|---|
| U1（旧P1a/P1b） | インストール済み / アカウントあり / オンボ未完了 | 招待リンク → 参加画面 → 認証（未ログイン時）→ 招待用オンボ（チーム名・招待ステップなし）→ 参加完了 | 期待どおり遷移し参加完了を確認済み | Pass |
| P2 | インストール済み / アカウントあり / オンボ完了 / ログイン済み / 未所属 | 招待リンク → 参加画面 → `参加してはじめる` → 即参加してホーム遷移 | 期待どおり即参加を確認済み | Pass |
| P3 | インストール済み / アカウントあり / オンボ完了 / 未ログイン / 未所属 | 招待リンク → 参加画面 → `参加してはじめる` → 既存アカウントログイン → 再オンボなしで参加完了 | 最新検証で参加完了まで確認済み（ブラウザフォールバック経由） | Pass（フォールバック導線） |
| P4a | 未インストール / 既存アカウントあり / オンボ完了 | 招待リンク（Web）→ TestFlight導線 → インストール → 再度招待導線 → 既存ログイン → 参加完了 | 最新検証で参加完了まで確認済み | Pass（フォールバック導線） |
| P4b | 未インストール / 既存アカウントあり / オンボ未完了 | 招待リンク（Web）→ インストール → 招待用オンボ（チーム名・招待ステップなし）→ 参加完了 | 期待どおり参加完了を確認済み | Pass |
| P5 | 未インストール / アカウントなし | 招待リンク（Web）→ インストール → 新規登録 → 招待用オンボ → 参加完了 | 最新検証で参加完了を確認済み | Pass |

## 2. 補足（通常フロー全体）
- 参加可否の観点では、通常パターン（U1/P2/P3/P4a/P4b/P5）で「参加できない」Failは最新時点で解消。
- ただし Universal Link の理想挙動（ブラウザを経由せず直接アプリ起動）は未達で、現状は Webフォールバック（`アプリで開く`）経由で成功。

## 3. 現状の到達フロー（通常パターン共通）
1. 招待リンク `https://kaeta-jointeam.com/invite/<inviteId>` を開く
2. 現状はブラウザでWebフォールバック画面が表示される
3. `アプリで開く` を押す
4. Kaetaの `参加してはじめる` 画面へ遷移
5. 受信者状態に応じて以下に分岐
   - 既存アカウント・オンボ完了: ログイン後に参加完了（再オンボなし）
   - 既存アカウント・オンボ未完了: 招待用オンボ経由で参加完了
   - 新規アカウント: 新規登録 + 招待用オンボ経由で参加完了

## 4. タスクシート（2026-02-26 時点）
### 4.1 今日の実施結果サマリ
| 区分 | タスク | ステータス | メモ |
|---|---|---|---|
| 認証 | Appleログイン失敗の詳細化 | 完了 | エラーメッセージに `SignInWithAppleAuthorizationException.message` を表示するよう修正済み。 |
| 認証 | Appleログイン実機再検証（新ビルド） | 継続 | 実機で `AuthorizationError error 1000` を確認。署名/配布設定由来の可能性が高い。 |
| 招待 | 新規アカウント直後の招待リンク作成FKエラー対応 | 完了（要再検証） | `families` のサーバー同期待ちを入れてから `create_invite` を実行するよう修正済み。 |
| UI | アイテム追加: `リストに追加する` を下部固定CTA化 | 完了 | `Scaffold.bottomNavigationBar` へ移設済み。 |
| UI | 候補バー位置を簡易追加と同様に調整 | 完了 | キーボード表示中は候補バーがキーボード上に出るよう修正済み。 |
| UI | アイテム名入力エリアを枠線なしに変更 | 完了 | 画像なし時: 左入力 + 右画像枠。 |
| UI | 写真追加時に全幅画像 + 下に入力欄 | 完了 | 画像プレビュー/削除/撮り直しUIを反映済み。 |

### 4.2 Appleログイン障害（明日再開用）
- 現象:
  - 実機/テストで `Appleログインに失敗しました（unknown）: The operation couldn’t be completed. (com.apple.AuthenticationServices.AuthorizationError error 1000.)`
- 切り分け結果:
  - `SignInWithApple.getAppleIDCredential()` 側で失敗（Supabaseに到達する前）。
  - アプリコード不具合より、署名/Capability/配布ビルド不整合の可能性が高い。
- 明日の実施手順（この順で実施）:
  1. Apple Developer > Identifiers > `com.kon-yuuki.kaetaSandbox` で `Sign In with Apple` 有効を再確認。
  2. 同App IDの App Store Provisioning Profile を再生成。
  3. GitHub Secrets `IOS_BUILD_PROVISION_PROFILE_BASE64` を新profileで更新。
  4. 必要なら `IOS_BUILD_CERTIFICATE_BASE64` も同一Teamの Apple Distribution証明書で更新。
  5. Actions `iOS TestFlight` で新ビルド配布。
  6. 実機で旧アプリ削除 → 最新ビルド再インストール → Appleログイン再試験。

### 4.3 招待リンクFKエラー（明日再開用）
- 旧エラー:
  - `insert or update on table "invitations" violates foreign key constraint "invitations_family_id_fkey"`
  - `Key (family_id)=... is not present in table "families"`
- 対応済み内容:
  - 招待作成前に `families.id` がサーバーに見えるまで短時間ポーリング待機する処理を追加。
  - `create_invite` 失敗時は `null` を返してUIで再試行可能にした。
- 明日の確認:
  1. 新規アカウント作成。
  2. オンボの招待ステップで `招待リンクをコピーする` 実行。
  3. FKエラーが再発しないことを確認。

### 4.4 変更済みファイル（2026-02-26）
- `lib/pages/login/view/login_screen.dart`
- `lib/pages/login/view/existing_account_login_screen.dart`
- `lib/pages/login/view/invite_auth_start_screen.dart`
- `lib/data/repositories/families_repository.dart`
- `lib/pages/home/todo_add_page.dart`
- `lib/pages/home/widgets/todo_add_sheet.dart`
