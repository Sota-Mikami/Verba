# Verba マネタイズ TODO

Created: 2026-03-08
Branch: `feature/license-system`（実装済み、マージ待ち）

## 概要

- 48時間トライアル → LemonSqueezy買い切り（1年有効期限付き）
- GitHub Sponsorsとの併用（Sponsors支援者には手動でキー送付）
- ソースはOSS公開のまま、署名済みバイナリに対して課金

## TODO

### LemonSqueezy セットアップ
- [ ] Store（販売者）アカウント作成: https://app.lemonsqueezy.com/register
  - Affiliateアカウントとは別。新規登録が必要
- [ ] 支払い受取設定（Settings → Payments → Stripe Connect or PayPal）
- [ ] 商品作成（Products → New Product）
  - Product type: **Software License**
  - Name: `Verba License (1 Year)` など
  - Price: 要決定（$4.99? $9.99?）
  - Activation limit: 2〜3（複数Mac対応）
  - License key expiration: **1 year**
- [ ] 商品URLを取得（Share → Store Page URL）

### コード反映
- [ ] `LicenseService.swift` の `lemonSqueezyStoreURL` に商品URLを設定
- [ ] `feature/license-system` ブランチをmainにマージ
- [ ] ビルド・動作確認（トライアル → 期限切れ → キー入力 → 有効化）
- [ ] CHANGELOG更新
- [ ] リリース

### GitHub Sponsors
- [ ] GitHub Sponsorsページをセットアップ（https://github.com/sponsors/Sota-Mikami）
- [ ] Sponsors向けの運用フロー決定
  - 案: 支援者にLemonSqueezyの0円クーポンを手動発行 → ライセンスキー取得
  - 案: 支援者にライセンスキーを直接DM送付

### 販売ページ・ドキュメント
- [ ] LemonSqueezy商品ページの説明文を用意
  - 含む内容: 機能概要、1年更新の説明、サポートはGitHub Issuesのみ
- [ ] LP (docs/index.html) に購入導線を追加
- [ ] README.mdに購入リンクを追加

### 将来検討
- [ ] Apple Developer Program ($99/year) でNotarization対応
- [ ] 価格調整（初期は安め → 機能追加に応じて改定）
- [ ] 学生・OSS開発者向け無料ライセンス制度

## 実装済みの機能（feature/license-system）

| 機能 | 状態 |
|------|------|
| 48時間トライアル（Keychain保存） | ✅ |
| LemonSqueezy activate API連携 | ✅ |
| LemonSqueezy validate API（週次再検証） | ✅ |
| ライセンス有効期限 (`expires_at`) 管理 | ✅ |
| 期限切れ時の録音ブロック | ✅ |
| ライセンスモーダルUI（購入リンク + キー入力） | ✅ |
| GitHub Sponsorsリンク | ✅ |
| サイドバーにトライアル残時間バッジ | ✅ |
| Debugビルドでライセンスバイパス | ✅ |
| EN/JA ローカライズ | ✅ |
| オフライングレース（validate失敗時は現状維持） | ✅ |

## 技術メモ

- activate/validate APIはpublic endpoint。サーバー側APIキー不要
- Keychainに保存するキー: `trialStartDate`, `licenseKey`, `activated`, `expiresAt`, `lastValidated`
- validate間隔: 7日（`LicenseConstants.validateIntervalSeconds`）
- トライアル期間: 48時間（`LicenseConstants.trialDurationSeconds`）
