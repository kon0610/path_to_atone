class ConsumerOffsetEvent < ApplicationRecord
  belongs_to :consumer_credit
  belongs_to :consumer_debt
end
