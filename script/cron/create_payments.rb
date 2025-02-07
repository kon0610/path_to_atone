module Cron
  class NettingBatch
    def self.run
      # バッチログから最新の実行時間を取得
      last_batch_executed_at = BatchLog.where(batch_name: 'NettingBatch').order(batch_executed_at: :desc).pluck(:batch_executed_at).first

      # データを取得
      receipts_with_data = Receipt
                           .joins(consumer_billing: { consumer_credits: :consumer_transaction })
                           .joins(:consumer_debt)
                           .where(consumer_billings: { payment_status: 0 })
                           .where(consumer_debts: { netting_datetime: nil })
                           .select(
                             'receipts.id AS receipt_id',
                             'receipts.payment_amount AS payment_amount',
                             'receipts.payment_date AS payment_date',
                             'consumer_billings.id AS consumer_billing_id',
                             'consumer_billings.initial_billing_amount AS initial_billing_amount',
                             'consumer_credits.id AS consumer_credit_id',
                             'consumer_credits.initial_consumer_credit AS initial_consumer_credit',
                             'consumer_debts.id AS consumer_debt_id',
                             'consumer_debts.initial_consumer_debt AS initial_consumer_debt',
                             'consumer_transactions.registration_datetime AS transaction_date'
                           )
                           .order('consumer_transactions.registration_datetime ASC') # 取引日時の昇順

      if receipts_with_data.empty?
        puts '該当する入金データがありません。処理を中断します。'
        exit 1 # 異常終了
      end

      # **債権と債務の相殺処理**
      ActiveRecord::Base.transaction do
        receipts_with_data.each do |data|
          # 最初に取得したデータを直接利用
          consumer_credit = ConsumerCredit.find(data.consumer_credit_id)
          consumer_debt = ConsumerDebt.find(data.consumer_debt_id)
          consumer_billing = ConsumerBilling.find(data.consumer_billing_id)
          receipt = Receipt.find(data.receipt_id)

          # 相殺イベント登録
          ConsumerOffsetEvent.create!(
            consumer_debt_id: consumer_debt.id,
            consumer_credit_id: consumer_credit.id,
            offset_datetime: Time.current,
            offset_amount: consumer_credit.initial_consumer_credit
          )

          # **データ更新**
          update_consumer_credit(consumer_credit)
          update_consumer_debt(consumer_debt)
          update_consumer_billing(consumer_billing)
          update_receipt_balance(receipt)
        end

        # **バッチ履歴の更新**
        log_execution('NettingBatch')
      end

      puts '相殺処理とデータ更新が完了しました。'
    rescue ActiveRecord::RecordNotFound => e
      puts "データベースのレコードが見つかりません: #{e.message}"
      exit 1
    rescue ActiveRecord::StatementInvalid => e
      puts "SQLエラーが発生しました: #{e.message}"
      exit 1
    rescue StandardError => e
      puts "予期しないエラーが発生しました: #{e.message}"
      exit 1
    end

    def self.update_consumer_credit(consumer_credit)
      offset_event = ConsumerOffsetEvent.find_by!(consumer_credit_id: consumer_credit.id)

      offset_amount = offset_event.offset_amount
      updated_credit = consumer_credit.initial_consumer_credit - offset_amount

      consumer_credit.update!(
        latest_consumer_credit: updated_credit,
        netting_datetime: offset_event.offset_datetime
      )
    end

    def self.update_consumer_debt(consumer_debt)
      offset_events = ConsumerOffsetEvent.where(consumer_debt_id: consumer_debt.id)

      total_offset_amount = offset_events.sum(:offset_amount)
      updated_debt = consumer_debt.initial_consumer_debt - total_offset_amount
      latest_offset_datetime = offset_events.maximum(:offset_datetime)

      consumer_debt.update!(
        latest_consumer_debt: updated_debt,
        netting_datetime: latest_offset_datetime
      )
    end

    def self.update_consumer_billing(consumer_billing)
      total_credit_balance = consumer_billing.consumer_credits.sum(:latest_consumer_credit)
      consumer_billing.update!(billing_balance: total_credit_balance)
      consumer_billing.update!(payment_status: 1)
    end

    def self.update_receipt_balance(receipt)
      consumer_debt = ConsumerDebt.find_by!(receipt_id: receipt.id)

      remaining_debt_balance = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
      receipt.update!(payment_balance: remaining_debt_balance)
    end

    def self.log_execution(batch_name)
      BatchLog.create!(
        batch_name: batch_name,
        batch_executed_at: Time.current
      )
    end
  end
end
