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
        member_code: 12345,
        )
      @consumer_billing = ConsumerBilling.create!(
        consumer_id: @consumer.id,
        initial_billing_amount: 1000,
        billing_balance: nil,
        payment_method: 0,
        billing_code: "55dbb150118e578d",
        payment_status: 0,
        payment_due_date: Date.new(2025, 1, 24),
        )
      @consumer_transaction1 = ConsumerTransaction.create!(
      consumer_id: @consumer.id,
      consumer_billing_id: @consumer_billing.id,
      amount: 300,
      registration_datetime: rand(1.month.ago..Time.current),
      )
      @consumer_transaction2 = ConsumerTransaction.create!(
        consumer_id: @consumer.id,
        consumer_billing_id: @consumer_billing.id,
        amount: 700,
        registration_datetime: rand(1.month.ago..Time.current),
      )

      @consumer_credit1 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction1.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction1.amount,
        latest_consumer_credit: nil,
        netting_datetime: nil,
      )
      @consumer_credit2 =ConsumerCredit.create!(
        consumer_id: @consumer.id,
        consumer_transaction_id: @consumer_transaction2.id,
        consumer_billing_id: @consumer_billing.id,
        initial_consumer_credit: @consumer_transaction2.amount,
        latest_consumer_credit: nil,
        netting_datetime: nil,
      )

      @receipt = Receipt.create!(
        consumer_billing_id: @consumer_billing.id,
        payment_amount: 1000,
        payment_balance: nil,
        payment_date: Date.new(2024, 12, 25),
        offset_completed_datetime: nil,
      )
      # puts "Receipt count: #{Receipt.count}"

      @consumer_debt = ConsumerDebt.create!(
        consumer_id: @consumer.id,
        receipt_id: @receipt.id,
        initial_consumer_debt: 1000,
        netting_datetime: nil,
      )
    end
    context "正常系：1000円の取引で全ての残高が0になる" do
      before do
        Cron::NettingBatch.run
      end
      it '入金の残高が0になっている' do
        expect(@receipt.reload.payment_balance).to eq(0)
      end
      
      it '請求の残高が0になっている' do
        expect(@consumer_billing.reload.billing_balance).to eq(0)
      end

      it '債務の残高が0になっている' do
        expect(@consumer_debt.reload.latest_consumer_debt).to eq(0)
      end

      it '債権の残高が0になっていること' do
        expect(@consumer_credit1.reload.latest_consumer_credit).to eq(0)
        expect(@consumer_credit2.reload.latest_consumer_credit).to eq(0)
      end

      it '相殺イベントが作成されていること' do
        event1 = ConsumerOffsetEvent.find_by(consumer_debt_id: @consumer_debt.id, consumer_credit_id: @consumer_credit1.id)
        event2 = ConsumerOffsetEvent.find_by(consumer_debt_id: @consumer_debt.id, consumer_credit_id: @consumer_credit2.id)
        expect(event1.reload.offset_amount).to eq(300)
        expect(event2.reload.offset_amount).to eq(700)
        expect(event1.reload.offset_datetime).to be_within(1.second).of(Time.current)
        expect(event2.reload.offset_datetime).to be_within(1.second).of(Time.current)
      end

      it 'バッチ履歴が記録されていること' do
        batch_log = BatchLog.find_by(batch_name: "NettingBatch")
        expect(batch_log.reload.batch_name).to eq('NettingBatch')
        expect(batch_log.reload.batch_executed_at).to_not be_nil
      end
    end

    context '異常系: 抽出データがない場合の標準出力' do
      before do
        Cron::NettingBatch.run
      end

      it "支払ステータスが 0 ではないデータではエラー" do
        @consumer_billing.update!(payment_status: 1) # 条件に合わないように更新
        @consumer_billing.reload
        puts @consumer_billing.inspect
        expect { Cron::NettingBatch.run }.to output(/⚠️  該当する入金データがありません。処理を中断します。/).to_stdout.and raise_error(SystemExit)
      end

      it "前回のbacth以前のデータが対象の時はエラー" do
        @consumer_debt.update!(netting_datetime: @latest_batch_time) # 直近バッチよりも前に設定
        @consumer_debt.reload
        puts "消し込み時間 #{@consumer_debt.reload.netting_datetime}"
        expect { Cron::NettingBatch.run }.to output(/⚠️  該当する入金データがありません。処理を中断します。/).to_stdout.and raise_error(SystemExit)
      end

      it "該当入金データがない場合、エラー" do
        # 全てのデータを削除して抽出対象がない状態を作る
        @receipt.destroy!
        @receipt.reload
        expect { Cron::NettingBatch.run }.to output(/⚠️  該当する入金データがありません。処理を中断します。/).to_stdout.and raise_error(SystemExit)
      end
    end
  end


end
