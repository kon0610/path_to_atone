class RenameTransactionsToConsumerTransactions < ActiveRecord::Migration[5.2]
  def change
    rename_table :transactions, :consumer_transactions
  end
end
