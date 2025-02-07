require 'rails_helper'
require_relative '../../script/cron/create_payments'

RSpec.describe Cron::NettingBatch, type: :module do
  describe '.run' do
    before do
      # バッチ履歴作成
      @latest_batch_time = 1.days.ago
      BatchLog.create!(
        batch_name: " NettingBatch",
        batch_executed_at: @latest_batch_time
      )
      # 条件に一致するデータを作成
      @consumer = Consumer.create!(
        full_name: "今美月",
        age: 25,
        phone_number: "09098765432",
        member_registration_datetime: rand(1.year.ago..Time.current),
        member_code: 12345
        )
      @consumer_billing = ConsumerBilling.create!(
        consumer_id: @consumer.id,
        initial_billing_amount: 1000,
        billing_balance: nil,
        payment_method: 0,
        billing_code: "55dbb150118e578d",
        payment_status: 0,
        payment_due_date: Date.new(2025, 1, 24)
        )
      @consumer_transaction1 = ConsumerTransaction.create!(
      consumer_id: @consumer.id,
      consumer_billing_id: @consumer_billing.id,
      amount: 300,
      registration_datetime: rand(1.month.ago..Time.current)
      )
      @consumer_transaction2 = ConsumerTransaction.create!(
        consumer_id: @consumer.id,
        consumer_billing_id: @consumer_billing.id,
        amount: 700,
        registration_datetime: rand(1.month.ago..Time.current)
      )

      @consumer_credit1 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction1.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction1.amount,
        latest_consumer_credit: nil,
        netting_datetime: nil
      )
      @consumer_credit2 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction2.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction2.amount,
        latest_consumer_credit: nil,
        netting_datetime: nil
      )

      @receipt = Receipt.create!(
        consumer_billing_id: @consumer_billing.id,
        payment_amount: 1000,
        payment_balance: nil,
        payment_date: Date.new(2024, 12, 25),
        offset_completed_datetime: nil
      )
      # puts "Receipt count: #{Receipt.count}"

      @consumer_debt = ConsumerDebt.create!(
        consumer_id: @consumer.id,
        receipt_id: @receipt.id,
        initial_consumer_debt: 1000,
        netting_datetime: nil
      )
    end
    context "正常系：1000円の取引で全ての残高が0になる" do
      it '入金,請求、債権、債務の残高が0になっている' do
        Cron::NettingBatch.run
        expect(@receipt.reload.payment_balance).to eq(0)
        expect(@consumer_billing.reload.billing_balance).to eq(0)
        expect(@consumer_debt.reload.latest_consumer_debt).to eq(0)
        expect(@consumer_credit1.reload.latest_consumer_credit).to eq(0)
        expect(@consumer_credit2.reload.latest_consumer_credit).to eq(0)
      end

      it '相殺イベントが作成されていること' do
        expect {
          Cron::NettingBatch.run
        }.to change { ConsumerOffsetEvent.count }.by(2)
      end

      it 'バッチ履歴が記録されていること' do
        expect {
          Cron::NettingBatch.run
        }.to change { BatchLog.count }.by(1)
      end
    end

    context '異常系: 抽出データがない場合の標準出力' do
      it "支払ステータスが 0 ではないデータではエラー" do
        @consumer_billing.update!(payment_status: 1) # 条件に合わないように更新
        expect {
          Cron::NettingBatch.run
        }.to raise_error(SystemExit).and output(/該当する入金データがありません。処理を中断します。/).to_stdout
      end

      it "前回のbacth以前のデータが対象の時はエラー" do
        @consumer_debt.update!(netting_datetime: @latest_batch_time) # 直近バッチよりも前に設定
        expect {
          Cron::NettingBatch.run
        }.to raise_error(SystemExit).and output(/該当する入金データがありません。処理を中断します。/).to_stdout
      end

      it "該当入金データがない場合、エラー" do
        # 全てのデータを削除して抽出対象がない状態を作る
        @receipt.destroy!
        expect {
          Cron::NettingBatch.run
        }.to raise_error(SystemExit).and output(/該当する入金データがありません。処理を中断します。/).to_stdout
      end
    end
  end


end
