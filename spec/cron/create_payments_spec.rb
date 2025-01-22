require 'rails_helper'
require_relative '../../script/cron/create_payments'

RSpec.describe Cron::NettingBatch, type: :module do
  describe '.run' do
    before do
      # バッチ履歴作成
      @latst_batch_time = 1.days.ago
      BatchLog.create!(
        batch_name: " NettingBatch",
        batch_executed_at: @latst_batch_time
      )
      # 条件に一致するデータを作成
      @consumer = Consumer.create!(
        full_name: "今美月",
        age: 25,
        phone_number: "09098765432",
        member_registration_datetime: rand(1.year.ago..Time.current),
        member_code: 12345,
        )
      @consumer_billing = ConsumerBilling.create!(
        consumer_id: @consumer.id,
        initial_billing_amount: 300,
        billing_balance: :nil,
        payment_method: 0,
        billing_code: "55dbb150118e578d",
        payment_status: 0,
        payment_due_date: Date.new(2025, 1, 24),
        )
      @consumer_transaction1 = ConsumerTransaction.create!(
      consumer_id: @consumer.id,
      consumer_billing_id: @consumer_billing.id,
      amount: 100,
      registration_datetime: rand(1.month.ago..Time.current),
      )
      @consumer_transaction2 = ConsumerTransaction.create!(
        consumer_id: @consumer.id,
        consumer_billing_id: @consumer_billing.id,
        amount: 200,
        registration_datetime: rand(1.month.ago..Time.current),
      )

      @consumer_credit1 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction1.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction1.amount,
        latest_consumer_credit: :nil,
        netting_datetime: :nil,
      )
      @consumer_credit2 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction2.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction2.amount,
        latest_consumer_credit: :nil,
        netting_datetime: :nil,
      )

      @receipt = Receipt.create!(
        consumer_billing_id: @consumer_billing.id,
        payment_amount: 300,
        payment_balance: nil,
        payment_date: Date.new(2024, 12, 25),
        offset_completed_datetime: nil,
      )
      @consumer_debt = ConsumerDebt.create!(
        consumer_id: @consumer.id,
        receipt_id: @receipt.id,
        initial_consumer_debt: 300,
        netting_datetime: nil,
      )
    end
    context "消し込み対象の入金データを抽出" do
      it '消し込み対象の入金データを抽出する' do
        expect { Cron::NettingBatch.run }
          .to output(/消し込み対象の入金データを1件抽出しました。/).to_stdout
      end
      it '消し込み対象の入金データが存在しないとき処理が終了する' do
        expect {Cron::NettingBatch.run }
          .to output(/消し込み対象の入金データはありませんでした。/).to_stdout
      end
    end
  end


end
