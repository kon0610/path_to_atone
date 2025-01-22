class RenameTransactionIdToConsumerTransactionIdInConsumerCredits < ActiveRecord::Migration[5.2]
  def change
    rename_column :consumer_credits, :transaction_id, :consumer_transaction_id
  end
end
