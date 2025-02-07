class CreateBatchLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :batch_logs do |t|
      t.string :batch_name, null: false
      t.date :batch_executed_at, null: false

      t.timestamps
    end
  end
end
