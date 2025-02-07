class CreateTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table :transactions do |t|
      t.references :consumer, foreign_key: true, null: false  # 購入者ID（外部キー）
      t.references :consumer_billing, foreign_key: true, null: true  # 請求ID（外部キー）
      t.integer :amount, null: false                          # 金額
      t.datetime :registration_datetime, null: false          # 登録日時
      t.timestamps
    end
  end
end
