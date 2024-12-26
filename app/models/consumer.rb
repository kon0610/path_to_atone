class Consumer < ApplicationRecord
  has_many :consumer_billings, dependent: :destroy
  has_one :consumer_credit, dependent: :destroy
  has_one :consumer_debt, dependent: :destroy
  has_many :consumer_transactions, dependent: :destroy
end
