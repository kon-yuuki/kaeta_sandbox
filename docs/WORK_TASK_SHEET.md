# WORK TASK SHEET

更新日: 2026-03-17

## 現在の残タスク

### 確認タスク

### 修正タスク
#### C. Push通知関連
- [ ] C-02 GitHub Actions の iOS TestFlight export が通るように CI 配布フローを修正
  - 現状:
    - `ARCHIVE SUCCEEDED` までは通る
    - `EXPORT FAILED` で `framework does not support provisioning profiles` に落ちる
    - Xcode / Organizer からは配布できるため、問題は app 本体ではなく CI の export 手順寄り
  - 確認できていること:
    - archive 済み `Runner.app` には `Push Notifications`, `Sign In with Apple`, `Associated Domains` が入っている
    - archive に埋め込まれた provisioning profile も同 profile を使っている
    - capability を単独にしても export failure は再現する
    - ローカル Xcode では provisioning profile を正しく選べば archive / 配布が進む
  - 次に確認すること:
    - Xcode Organizer で成功した配布方法と、Actions の `ExportOptions.plist` / export 手順の差分整理
    - `xcodebuild -exportArchive` の署名指定を framework へ波及させない形へ見直す
    - 必要なら Actions ではなく App Store Connect へのアップロード方式そのものを見直す

#### A. 認証導線まわり
- [ ] A-08 設定画面から後付けでメール・Google・Appleアカウント連携ができるよう修正
  - 切り分け方:
    - 後からメール認証
    - 後から Google 認証
    - 後から Apple 認証
  - 現状: メールアドレスでアカウント作成後に Google 連携を行うと、認証完了までは進むが、その後 `kaeta-jointeam.com` に遷移して `Coming Soon` が表示されていた
  - 現状: Google 認証済みアカウントに後からメール認証を追加しようとすると、新しいメールアドレスにもメールは届くが迷惑メールに入ることがある
  - 現状: 後からメール認証で届いたメールの `Change email` をタップすると `kaeta-jointeam.com` に遷移して `Coming Soon` が表示される
  - 現状: 後から Apple 認証を追加すると `appleid.apple.com` に遷移し、Face ID までは成功するが、その後アプリ側で「登録に失敗しました」になって連携できない
  - 2026-03-16 実機確認: 設定画面の `Apple > 連携する` を押すと `PlatformException(Error, Error while launching https://appleid.apple.com/auth/authorize?...client_id=com.kon-yuuki.kaetaSandbox..., null, null)` が表示され、Face ID 前に失敗するケースを確認
  - 原因調査メモ:
    - 設定画面の後付け Apple 連携は `sign_in_with_apple` を使わず `supabase.auth.linkIdentity(OAuthProvider.apple, redirectTo: kaeta://auth/callback)` を呼んでいる
    - そのためネイティブの Apple サインインではなく、Supabase の Web OAuth フローとして `https://appleid.apple.com/auth/authorize` を外部起動しようとしている
    - 実機エラー URL では `client_id=com.kon-yuuki.kaetaSandbox` が使われており、Apple Web OAuth 用の Service ID ではなく iOS の bundle id を使っている可能性が高い
    - ログイン画面の Apple 認証は `SignInWithApple.getAppleIDCredential(...) -> supabase.auth.signInWithIdToken(...)` で実装されており、設定画面の連携方式と実装経路が揃っていない
  - 期待動作: Google 認証済みアカウントに後からメール認証を追加する場合は、メール認証で設定したメールアドレス宛にメールアドレス変更メールを送り、`Change email` 後は `kaeta-jointeam.com` ではなくアプリへ復帰する
  - 対応済み: 設定画面の `linkIdentity` に `redirectTo=kaeta://auth/callback` を指定し、OAuth 連携後にアプリへ復帰するよう変更
  - 完了条件: 後から Google 連携したときに `kaeta-jointeam.com` へ遷移せずアプリへ戻ること
  - 完了条件: 後から Apple 連携したときに Face ID 後の登録失敗が起きず、連携完了できること
  - 完了条件: 後からメール認証したときに、新しいメールアドレス宛に正しいメールが届き、`Change email` 後に `kaeta-jointeam.com` ではなくアプリへ戻ること
- [ ] A-15 アプリ起動中に招待リンクを踏んだとき、アプリへ遷移しても「参加してはじめる」画面が表示されない問題を修正
  - 現状: アプリを開いている状態で招待リンクを踏くとアプリ自体には遷移するが、`参加してはじめる` 画面へ進まない
  - 期待動作: アプリがフォアグラウンドでもバックグラウンドでも、招待リンク受信時は該当の `参加してはじめる` 画面を表示すること
- [ ] A-16 チーム未所属状態でアカウント削除したときも、ゲストモードへ残らずスタート画面へ遷移するよう修正
  - 現状: チーム所属中にアカウント削除した場合はスタート画面へ戻るが、チームを削除して未所属状態になってからアカウント削除するとゲストモードになってしまう
  - 期待動作: チーム所属の有無に関係なく、アカウント削除後は認証状態を完全に解消してスタート画面へ戻ること

kon@quoitworks.com
b3113016
