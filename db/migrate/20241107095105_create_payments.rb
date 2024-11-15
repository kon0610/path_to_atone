class CreatePayments < ActiveRecord::Migration[5.2]
  def change
    create_table :payments do |t|
      t.integer  :amount
      t.datetime :payment_time
      

      t.timestamps
    end
  end
end
