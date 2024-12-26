class ConsumerTransaction < ApplicationRecord
  belongs_to :consumer
  belongs_to :consumer_billing, optional: true
  has_one :consumer_debt, dependent: :destroy
  has_one :consumer_credit, dependent: :destroy
end
