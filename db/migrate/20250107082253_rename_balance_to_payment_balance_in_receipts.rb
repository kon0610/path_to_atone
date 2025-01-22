class RenameBalanceToPaymentBalanceInReceipts < ActiveRecord::Migration[5.2]
  def change
    rename_column :receipts, :balance, :payment_balance
  end
end
