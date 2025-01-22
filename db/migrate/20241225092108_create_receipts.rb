class CreateReceipts < ActiveRecord::Migration[5.2]
  def change
    create_table :receipts do |t|
      t.references :consumer_billing, foreign_key: true, null: false  # 請求ID (外部キー)
      t.integer :payment_amount, null: false                           # 支払金額
      t.integer :balance, null: true                                    # 残額
      t.date :payment_date, null: false                                # 支払日
      t.datetime :offset_completed_datetime, null: true               # 消込完了時間

      t.timestamps
    end
  end
end
