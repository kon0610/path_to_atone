class ConsumerBilling < ApplicationRecord
  has_many :consumertransactions, dependent: :destroy
  has_many :consumer_credits, dependent: :destroy
  has_one :receipt, dependent: :destroy
  belongs_to :consumer
end
