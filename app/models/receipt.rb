class Receipt < ApplicationRecord
  belongs_to :consumer_billing
  has_one :consumer_debt, dependent: :destroy

end
