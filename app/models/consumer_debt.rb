class ConsumerDebt < ApplicationRecord
    belongs_to :consumer
    belongs_to :receipt
    has_many :consumer_offset_events, dependent: :destroy
end

