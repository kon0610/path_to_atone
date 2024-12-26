class ConsumerCredit < ApplicationRecord
  has_many :consumer_offset_events, dependent: :destroy
  belongs_to :consumer_billing, optional: true
  belongs_to :consumer_transaction, foreign_key: 'consumer_transaction_id', optional: true
  belongs_to :consumer
end
