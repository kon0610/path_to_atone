require 'rails_helper'
require_relative '../../script/cron/create_payments'

RSpec.describe 'Cron::CreatePayments', type: :module do
  describe '.run' do
    let(:payment_count_before) { Payment.count }

    it '新しいPaymentレコードを作成する' do
      expect { Cron::CreatePayments.run }.to change(Payment, :count).by(1)
    end

    it '作成されたPaymentレコードの内容が正しい' do
      Cron::CreatePayments.run
      payment = Payment.last
      expect(payment.amount).to eq(1000)
      expect(payment.payment_time).to be_within(1.second).of(Time.current)
    end
  end
end
