class CreateConsumercredits < ActiveRecord::Migration[5.2]
  def change
    create_table :consumer_credits do |t|
      t.references :consumer, foreign_key: true, null: false       # 購入者ID (外部キー)
      t.references :transaction, foreign_key: true, null: false    # 取引ID (外部キー)
      t.references :consumer_billing, foreign_key: true, null: true # 請求ID (外部キー)
      t.integer :initial_consumer_credit, null: false              # 初期債権
      t.integer :latest_consumer_credit, null: true              # 残債権
      t.datetime :netting_datetime, null: true                    # 消込時間
      t.datetime :created_at, null: true                         # 登録日時

      t.timestamps
    end
  end
end
