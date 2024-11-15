# 入金管理システム
---

### 概要
---
このアプリケーションは、ユーザーが入金金額を入力し、入金データを管理するためのシンプルな入金管理システムです。入金後、ユーザーは入金完了画面を確認できます。

---
#### 機能一覧
---
- 入金金額の入力
- 入金日時の自動登録
- 入金データの保存と確認
- 入金完了画面の表示

---
#### 技術スタック
---
- **フレームワーク**: Ruby on Rails 5.2
- **プログラミング言語**: Ruby 2.5.9
- **データベース**: PostgreSQL
- **テスト**: RSpec

---
#### 使用方法
1.入金画面で金額を入力し、入金ボタンをクリックします。
2.入金データがデータベースに保存され、入金完了画面に遷移します。
3.入金情報は show アクションで確認できます。

---
#### テスト方法
- テストの実行
```bundle exec rspec```
