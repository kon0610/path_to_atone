class CreateConsumerdebts < ActiveRecord::Migration[5.2]
  def change
    create_table :consumer_debts do |t|
      t.references :consumer, foreign_key: true, null: false                  # 購入者ID (外部キー)
      t.references :receipt, foreign_key: true, null: false                   # 入金ID (外部キー)
      t.integer :initial_consumer_debt, null: false                           # 初期債務
      t.integer :latest_consumer_debt, null: true                            # 残債務
      t.datetime :netting_datetime, null: true                               # 消込時間
      t.datetime :created_at, null: true                                     # 登録日時
      t.timestamps
    end
  end
end
