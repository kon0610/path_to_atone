class CreateConsumeroffsetevents < ActiveRecord::Migration[5.2]
  def change
    create_table :consumer_offset_events do |t|
      t.references :consumer_debt, foreign_key: true, null: true  # 購入者債務ID (外部キー)
      t.references :consumer_credit, foreign_key: true, null: true   # 購入者債権ID (外部キー)
      t.datetime :offset_datetime, null: false  # 相殺日時
      t.integer :offset_amount, null: false  # 相殺金額

      t.timestamps
    end
  end
end
