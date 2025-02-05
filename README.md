# NettingBatch (満額入金に対する消し込み処理バッチ)

## 概要

`Cron::NettingBatch` は、消し込み処理を行うバッチスクリプトです。  
このバッチは、請求に紐づいている満額の入金データと債務・債権データをマッチングし、相殺処理を実行します。  
### 前提
データは以下条件で既に存在している状態とする
- 購入者と紐づく取引・請求・債権が既に存在している  
- 入金と紐づく債務が既に存在している  
- 入金は請求と紐づいている  
- 債権と債務は紐づいていない

## 動作概要

### 正常系の処理フロー

#### データ抽出

`ConsumerBilling`（請求データ）、`ConsumerCredit`（債権データ）、`ConsumerDebt`（債務データ）を抽出

`Receipt`（入金データ）がある場合、相殺処理の対象とする

#### 相殺処理

`ConsumerDebt` の金額を `ConsumerCredit` で相殺する

`ConsumerBilling` の残高 `billing_balance` を 0 にする

`ConsumerCredit` の残高 `latest_consumer_credit` を 0 にする

`ConsumerDebt` の残高 `latest_consumer_debt` を 0 にする

#### 相殺イベントの作成

`ConsumerOffsetEvent` を作成し、相殺したデータを記録する

#### バッチ履歴の作成

`BatchLog` にバッチ実行履歴を記録

### 異常系の処理フロー

#### 支払ステータスが 0 ではない場合

`payment_status` が 0 以外の `ConsumerBilling` は対象外

`⚠️  該当する入金データがありません。処理を中断します。` と出力し、SystemExit を発生

#### 前回のバッチ以前のデータが対象の場合

`netting_datetime` が `latest_batch_time` より前の `ConsumerDebt` は対象外

`⚠️  該当する入金データがありません。処理を中断します。` と出力し、SystemExit を発生

#### 該当入金データがない場合
`Receipt` が存在しない

`⚠️  該当する入金データがありません。処理を中断します。` と出力し、SystemExit を発生

## テスト概要

### 正常系テスト

`1000円の取引で全ての残高が0になる`

  - 支払残額 が 0 になることを確認

  - 請求残高 が 0 になることを確認

  - 残債務 が 0 になることを確認

  - 残債権 が 0 になることを確認

  - 相殺イベントが登録正しくされるか確認

  - bacthの履歴が記録されることを確認

### 異常系テスト

支払ステータスが 0 ではないデータではエラー

 - `payment_status` を 1 に変更し、バッチ実行時に SystemExit 例外が発生することを確認

前回のバッチ以前のデータが対象の時はエラー

 - `netting_datetime` を `latest_batch_time` に変更し、バッチ実行時に SystemExit 例外が発生することを確認

該当入金データがない場合、エラー

`Receipt` を削除し、バッチ実行時に SystemExit 例外が発生することを確認

### 実行方法

バッチの実行は以下のコマンドで行います。
```
rails c
require_relative 'ファイル名'
Cron:: NettingBatch.run
```

テストを実行する場合は、以下のコマンドを使用します。

`bundle exec rspec ファイル名`

### 注意点

バッチ実行前に、データベースの整合性を確認してください。

既存の BatchLog に影響を与えないように、適切なバッチ実行時間を設定してください。

テスト実行時は、事前に適切なテストデータを作成してください。


