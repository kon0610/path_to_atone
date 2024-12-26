class CreateConsumerBillings < ActiveRecord::Migration[5.2]
  def change
    create_table :consumer_billings do |t|
      t.references :consumer, foreign_key: true, null: false       # 購入者ID (外部キー)
      t.integer :initial_billing_amount, null: false               # 初回請求金額
      t.integer :billing_balance, null: true                      # 請求残高
      t.integer :payment_method, null: false                       # 支払い手段
      t.string :billing_code, null: false                          # 請求コード
      t.integer :payment_status, null: false                       # 支払い状態
      t.date :payment_due_date, null: false                        # 支払い期日
      t.timestamps
    end
  end
end
