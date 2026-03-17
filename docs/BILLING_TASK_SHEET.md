# BILLING TASK SHEET

更新日: 2026-03-17

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

### 3. アプリ実装

- [ ] `purchases_flutter` 導入
- [ ] RevenueCat 初期化処理追加
- [ ] Supabase user id を `appUserID` として連携
- [ ] `basic` / `premium` entitlement を読む provider 作成
- [ ] debug override 実装
  - `system`
  - `forceFree`
  - `forceBasic`
  - `forcePremium`
- [ ] 課金状態確認 UI / デバッグ UI 実装
- [ ] 最初の課金制御対象を 1 箇所に導入
  - 候補: カテゴリ上限

### 4. テスト

- [ ] RevenueCat Test Store で未課金 / ベーシック / プレミアムの切り替え確認
- [ ] アプリ内で課金状態反映を確認
- [ ] Sandbox / TestFlight で購入・復元確認
- [ ] アカウント切替時の課金状態同期確認

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

1. RevenueCat 側で不要な初期 product が残っていれば削除して整理
2. Flutter 側に `purchases_flutter` を導入
3. RevenueCat 初期化と課金状態 provider を実装
4. debug override を作り、未課金 / ベーシック / プレミアムを手元で切り替えられるようにする
5. 最初の制御対象としてカテゴリ上限を課金状態に接続する

## メモ

- 現時点では App Store Connect は未設定
- そのため最初の動作確認は RevenueCat Test Store を使う
- Secret API key は今は不要
- Flutter アプリに入れるのは Public SDK API key のみ
