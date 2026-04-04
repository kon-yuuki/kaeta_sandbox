# BILLING TASK SHEET

更新日: 2026-03-31

## 目的

- iOS 向けにサブスクリプション課金を導入する
- 無料 / ベーシック / プレミアムの 3 状態をアプリ内で扱えるようにする
- RevenueCat を課金状態の基盤にしつつ、開発中はデバッグ用 override で
  `未課金 / ベーシック / プレミアム` を強制できるようにする

## 現在の方針

- 対象プラットフォーム: iOS
- 課金種別: 自動更新サブスク
- 課金基盤: RevenueCat
- 実装方針:
  - 先に RevenueCat + アプリ側の土台を入れる
  - その後 App Store Connect の本番商品へ接続する
  - 開発中は Test Store と debug override で動作確認する

## 現在の最優先

- TestFlight 実機でアプリをクラッシュさせず起動できる状態にする
- TestFlight 実機で、シミュレータと同様に `system` でプラン切り替え確認ができる状態にする
- 上記ができるまで、課金以外の実機デバッグはブロックされている前提で進める

## 現在のブロッカー

- Release / TestFlight で使う production Public SDK key は取得済み
- まだ production key を渡した TestFlight ビルドでの起動確認が未実施
- RevenueCat product と App Store Connect 商品の接続が未完了のため、起動後に `system` で offering / package を正常取得できるかは未確認

## 現在の進捗

### 1. RevenueCat 設定

- [x] RevenueCat プロジェクト作成
- [x] Public SDK API key 確認
  - Test Store Public API key:
    - `test_trupjfHbxCMUBMXTlDfXdSDhTaA`
- [x] Entitlements 作成
  - `basic`
  - `premium`
- [x] Products 作成
  - `kaeta_basic_monthly`
  - `kaeta_premium_monthly`
- [x] Offering `default` 作成 / 整理
- [x] Packages 紐付け
  - `basic` -> `kaeta_basic_monthly`
  - `premium` -> `kaeta_premium_monthly`
- [x] 不要な初期自動作成 product が残っていれば削除して整理

### 2. App Store Connect 設定

- [ ] Paid Applications Agreement 締結
- [ ] Banking / Tax 設定
- [ ] Subscription Group 作成
  - 推奨名: `Kaeta Plans`
- [ ] 本番商品作成
  - `kaeta_basic_monthly`
  - `kaeta_premium_monthly`
- [ ] RevenueCat 側 product を App Store Connect 商品へ接続

### 2.5. TestFlight 先行確認のための暫定対応

- [x] Release / TestFlight ビルドで production Public SDK key を使うよう切替
- [ ] Debug / Simulator / 直接実機起動では Test Store Public SDK key を使うよう切替
- [ ] TestFlight で起動時クラッシュが出ないことを確認
- [ ] TestFlight で `system` 状態の課金読込が失敗せず画面操作できることを確認

### 3. アプリ実装

- [x] `purchases_flutter` 導入
- [x] RevenueCat 初期化処理追加
- [x] Supabase user id を `appUserID` として連携
- [x] `basic` / `premium` entitlement を読む provider 作成
- [x] debug override 実装
  - `system`
  - `forceFree`
  - `forceBasic`
  - `forcePremium`
- [x] 課金状態確認 UI / デバッグ UI 実装
- [x] 最初の課金制御対象を 1 箇所に導入
  - カテゴリ上限

### 4. テスト

- [x] RevenueCat Test Store で未課金 / ベーシック / プレミアムの切り替え確認
- [x] debug override で free / basic / premium の切り替え確認
- [x] アプリ内でカテゴリ上限反映を確認
- [ ] Sandbox / TestFlight で購入・復元確認
- [ ] TestFlight で `system` によるプラン状態表示確認
- [ ] アカウント切替時の課金状態同期確認

### 5. プラン差分 UI / 導線整理

- [x] BP-01 有料プラン詳細をボトムシートではなく専用ページへ変更する
  - 対象:
    - `lib/pages/setting/view/premium_plan_sheet.dart`
    - `lib/pages/setting/view/setting_screen.dart`
  - 対応方針:
    - 既存のボトムシート UI を流用しつつ、`PremiumPlanPage` のような通常ページへ移す
    - `showPremiumPlanSheet(context)` ベースの呼び出しはページ遷移用 helper に置き換える
    - プラン選択 UI はページ内で状態保持し、選択中プランに応じて購入 CTA の挙動を切り替える
  - 完了条件:
    - 設定画面の有料プランバナー押下でボトムシートではなく詳細ページへ遷移する
    - 戻る操作で自然に元画面へ戻れる

- [x] BP-02 他画面の有料プラン導線もすべて専用ページ遷移へ統一する
  - 現在 `showPremiumPlanSheet(context)` を呼んでいる主な箇所:
    - `lib/pages/home/widgets/history_add_view.dart`
    - `lib/pages/home/widgets/todo_add_sheet.dart`
    - `lib/pages/setting/view/setting_screen.dart`
  - 対応方針:
    - ボトムシート起動箇所を全検索し、`Navigator.push(...)` ベースの共通導線に寄せる
    - どのバナー / CTA からも同じ有料プラン詳細ページへ遷移させる
  - 完了条件:
    - ボトムシート起動が残らない
    - 各導線が同じページへ遷移する

- [x] BP-02a 有料プラン詳細ページの CTA を選択中プランの購入フローに接続する
  - 対象:
    - 有料プラン詳細ページ本体
    - 必要に応じて `lib/data/providers/billing_provider.dart` / `BillingService`
  - 前提:
    - ページ上で `basic` / `premium` のどちらかを選択できる状態にする
    - 選択だけでは課金開始せず、下部 CTA 押下時にのみ購入を開始する
  - 対応方針:
    - `basic` 選択中は RevenueCat の basic package を購入
    - `premium` 選択中は RevenueCat の premium package を購入
    - CTA 押下で `purchasePackage(...)` を呼び、iOS の購入シートを表示する
    - 購入成功後は entitlement 更新を通じてプラン状態へ反映する
  - 完了条件:
    - 選択中プランに応じて正しい購入シートが表示される
    - 選択状態だけでは購入が始まらない
    - 購入完了後に `basic` / `premium` 状態へ反映される

- [ ] BP-02b 実機確認: 無料体験つき購入時の表示と状態反映を確認する
  - 前提:
    - 無料体験の有無と期間は App Store Connect 側の商品設定に依存する
    - アプリ側は通常購入と同様に `purchasePackage(...)` を起点とする
  - 対応方針:
    - 購入シート上で無料体験が表示される構成を前提に動作確認する
    - 無料体験開始後も entitlement が active になり、該当プラン機能が解放される前提で扱う
  - 完了条件:
    - 無料体験付き商品で購入シートに無料体験文言が表示される
    - 無料体験開始後にプラン状態が有効になる

- [x] BP-03 購入履歴ページの「購入頻度が高い」セクションをプレミアム限定表示にする
  - 対象:
    - `lib/pages/home/widgets/history_add_view.dart`
    - 必要に応じて `lib/data/providers/billing_provider.dart`
  - 現状:
    - `history_add_view.dart` で「購入頻度が高い」セクションが常時描画されている
  - 対応方針:
    - `billingState.hasPremium` を使って、プレミアム以外ではセクションごと非表示にする
  - 完了条件:
    - free / basic では「購入頻度が高い」が表示されない
    - premium では従来どおり表示される

- [x] BP-04 アイテム追加・編集画面のカテゴリ追加時プレミアム導線をページ遷移へ変更する
  - 対象:
    - `lib/pages/home/widgets/todo_add_sheet.dart`
    - `lib/pages/home/widgets/category_edit_sheet.dart`
  - 現状:
    - カテゴリ追加時の上限到達導線でプレミアムプランモーダル / ボトムシートを開く経路がある
  - 対応方針:
    - 上限到達時の CTA は有料プラン詳細ページへ直接遷移する
    - モーダルを閉じたあとに詳細を開くのではなく、遷移導線を統一する
  - 完了条件:
    - アイテム追加画面 / 編集画面のカテゴリ追加導線でボトムシートが開かない
    - 有料プラン詳細ページへ遷移する

- [x] BP-05 有料プラン詳細の 2 プラン切替 UI のレイアウト崩れを修正する
  - 対象:
    - `lib/pages/setting/view/premium_plan_sheet.dart`
    - ページ化後にファイル名を変更する場合は移行先ページ側
  - 現状:
    - 2つのプランを選べるトグル / セレクタ周辺で `RenderFlex overflowed by 42 pixels on the bottom` が発生している
    - エラーログ上の該当箇所は `premium_plan_sheet.dart:920` 付近の `Column`
  - 対応方針:
    - 固定高さに依存しているレイアウトを見直し、縦方向に収まる構成へ変更する
    - 必要に応じて `Expanded` / `Flexible` / スクロール化 / 余白調整を行う
    - basic / premium の両状態で選択UIが崩れず切り替えできることを優先する
  - 完了条件:
    - 有料プラン詳細のプラン切替 UI で overflow が発生しない
    - ベーシック / プレミアムの切替表示と CTA が正しく見える
    - 画面サイズが小さい端末でも下部が見切れない

#### 実機確認タスク

- [ ] BP-06 実機確認: 選択中プランに応じて正しい iOS 購入シートが表示される
  - 確認観点:
    - ベーシック選択時に basic package の購入シートが出る
    - プレミアム選択時に premium package の購入シートが出る
    - プラン選択だけでは課金が始まらず、CTA 押下時のみ購入フローへ進む

- [ ] BP-07 実機確認: 購入完了後に entitlement 反映でプラン状態が更新される
  - 確認観点:
    - 購入成功後に `basic` / `premium` 状態へ反映される
    - 対応する制限解除 UI が即時または再表示で正しく変わる

- [ ] BP-08 実機確認: 無料体験文言と無料体験開始後の状態反映を確認する
  - 確認観点:
    - App Store の購入シートに無料体験文言が出る
    - 無料体験開始後も entitlement が active になり、該当プラン機能が解放される

#### 実装メモ

- `showPremiumPlanSheet(context)` 呼び出し箇所は実装前に再検索すること
- 画面名は仮で `PremiumPlanPage` とし、既存の `premium_plan_sheet.dart` はページ化に合わせて改名を検討する
- 設定画面とホーム配下で導線が分散しているため、遷移 helper を 1 箇所に寄せると今後の変更コストが下がる
- RevenueCat の購入開始は「プラン選択時」ではなく「CTA ボタン押下時」
- 無料体験がある場合もアプリ側は通常購入と同じ導線でよく、違いは購入シート表示内容と entitlement の有効化タイミング

## 決まっていること

- プラン構成:
  - 無料
  - ベーシック
  - プレミアム
- RevenueCat 側の package 構成:
  - `basic`
  - `premium`
- 最終的にアプリ側では以下のような判定を持つ想定:
  - `hasBasicOrAbove = basic || premium`
  - `hasPremium = premium`

## 次にやること

1. production key を `--dart-define` 付きで TestFlight 用ビルドに入れて配布する
2. TestFlight 実機で `Wrong API Key` が出ず起動継続できることを確認する
3. TestFlight 実機で設定画面の `system` 状態が開けることを確認する
4. RevenueCat product と App Store Connect 商品の接続状況を確認する
5. 接続不足があれば `kaeta_basic_monthly` / `kaeta_premium_monthly` を接続する
6. その後に購入・復元・アカウント切替同期確認へ進む

## メモ

- 現時点では App Store Connect は未設定
- そのため最初の動作確認は RevenueCat Test Store を使う
- Secret API key は今は不要
- Flutter アプリに入れるのは Public SDK API key のみ
- TestFlight で test key は使用できない
- TestFlight で擬似確認を優先する場合も、RevenueCat 側は production key が必要
- production Public SDK key:
  - `appl_lTdSpHjqbVbBbywdRslLuPTsoXD`
- プラン差分と課金文言の整理は [BILLING_PLAN_SPEC.md](/Users/kon/private-develop/wip/Kaeta/kaeta_sandbox/docs/BILLING_PLAN_SPEC.md) を参照
- 2026-03-17:
  - Flutter 側に `BillingService` / `billingControllerProvider` を追加
  - `main.dart` で RevenueCat 初期化と Supabase auth 連動の login/logout を追加
  - 設定画面に debug override UI を追加
  - カテゴリ上限を free=3 / basic=5 / premium=無制限 に接続
  - debug override でカテゴリ上限切り替え確認済み
  - RevenueCat Test Store の `system` で basic / premium の実状態確認済み
  - `system` 状態でカテゴリ上限反映も確認済み
- 2026-03-18:
  - TestFlight 実機で `Wrong API Key` により起動継続できないことを確認
  - 以降の最優先は「TestFlight でクラッシュせず起動し、`system` でプラン状態を確認できること」とする
  - RevenueCat に App Store app を追加し、production Public SDK key を取得
  - Flutter 側は Release / TestFlight で `REVENUECAT_APPLE_PRODUCTION_SDK_KEY` を受け取る実装へ変更済み
  - 次の確認は production key を付けた TestFlight ビルドでの起動可否
