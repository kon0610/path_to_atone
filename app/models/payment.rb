class Payment < ApplicationRecord
    validates :amount, presence: true
    validates :payment_time, presence: true
end
