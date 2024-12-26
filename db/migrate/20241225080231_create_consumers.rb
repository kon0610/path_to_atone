class CreateConsumers < ActiveRecord::Migration[5.2]
  def change
    create_table :consumers do |t|
      t.string :full_name, null: false # 氏名
      t.integer :age, null: false      # 年齢
      t.string :phone_number, null: false # TEL
      t.datetime :member_registration_datetime, null: false # 会員登録日時
      t.integer :member_code, null: false, unique: true # 会員コード

      t.timestamps # created_at, updated_at
    end

    add_index :consumers, :member_code, unique: true # 会員コードに一意性制約を追加
  end
end
