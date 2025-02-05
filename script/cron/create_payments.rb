require_relative '../../config/environment'

module Cron
  class NettingBatch
    def self.run
      begin
        # バッチログから最新の実行時間を取得
        last_batch_executed_at = BatchLog.where(batch_name: 'NettingBatch').order(batch_executed_at: :desc).pluck(:batch_executed_at).first
        puts "最終実行時間: #{last_batch_executed_at}"

        # データを取得
        receipts_with_data = Receipt
        .joins(consumer_billing: { consumer_credits: :consumer_transaction })
        .joins(:consumer_debt)
        .where(consumer_billings: { payment_status: 0 })
        .where.not(payment_amount: nil)
        .where("consumer_debts.netting_datetime IS NULL OR consumer_debts.netting_datetime > ?", last_batch_executed_at || Time.at(0))
        .select(
          "receipts.id AS receipt_id",
          "receipts.payment_amount AS payment_amount",
          "receipts.payment_date AS payment_date",
          "consumer_billings.id AS consumer_billing_id",
          "consumer_billings.initial_billing_amount AS initial_billing_amount",
          "consumer_credits.id AS consumer_credit_id",
          "consumer_credits.initial_consumer_credit AS initial_consumer_credit",
          "consumer_debts.id AS consumer_debt_id",
          "consumer_debts.initial_consumer_debt AS initial_consumer_debt",
          "consumer_transactions.registration_datetime AS transaction_date"
        )
        .order("consumer_transactions.registration_datetime ASC") # 取引日時の昇順

        if receipts_with_data.empty?
          puts "⚠️  該当する入金データがありません。処理を中断します。"
          exit 1 # 異常終了
        end

        # **データの件数を出力**
        puts "========================="
        puts "データ抽出結果"

        #　ここのデータを使って相殺処理する
        receipt_ids = receipts_with_data.map(&:receipt_id).uniq
        billing_ids = receipts_with_data.map(&:consumer_billing_id).uniq
        credit_ids = receipts_with_data.map(&:consumer_credit_id).uniq
        debt_ids = receipts_with_data.map(&:consumer_debt_id).uniq

        puts "消し込み対象の入金データを#{receipt_ids.size}件抽出しました。"
        puts "請求データ: #{billing_ids.size} 件"
        puts "債権データ: #{credit_ids.size} 件"
        puts "債務データ: #{debt_ids.size} 件"
        puts "========================="

        # **債権と債務の相殺処理**
        ActiveRecord::Base.transaction do
          receipts_with_data.each do |data|
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

            puts "✅  相殺処理を実行: 債権ID #{consumer_credit.id}, 債務ID #{consumer_debt.id}, 相殺金額 #{consumer_credit.initial_consumer_credit}"

            # **データ更新**
            update_consumer_credits([consumer_credit])
            update_consumer_debt(consumer_debt)
            update_consumer_billing(consumer_billing)
            update_receipt_balance(receipt)
          end

          # **バッチ履歴の更新**
          log_execution('NettingBatch')
        end

        puts "🎉  相殺処理とデータ更新が完了しました。"

      rescue ActiveRecord::RecordNotFound => e
        puts "⚠️  データベースのレコードが見つかりません: #{e.message}"
        exit 1
      rescue ActiveRecord::StatementInvalid => e
        puts "⚠️  SQLエラーが発生しました: #{e.message}"
        exit 1
      rescue StandardError => e
        puts "⚠️  予期しないエラーが発生しました: #{e.message}"
        exit 1
      end
    end

    private

    def self.update_consumer_credits(consumer_credits)
      consumer_credits.each do |credit|
        offset_event = ConsumerOffsetEvent.find_by!(consumer_credit_id: credit.id)

        offset_amount = offset_event.offset_amount
        updated_credit = credit.initial_consumer_credit - offset_amount

        credit.update!(
          latest_consumer_credit: updated_credit,
          netting_datetime: offset_event.offset_datetime
        )

        # puts "🔄  債権更新: 債権ID #{credit.id}, 最新債権残高 #{updated_credit}"
      end
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

      # puts "🔄  債務更新: 債務ID #{consumer_debt.id}, 最新債務残高 #{updated_debt}"
    end

    def self.update_consumer_billing(consumer_billing)
      total_credit_balance = consumer_billing.consumer_credits.sum(:latest_consumer_credit)
      consumer_billing.update!(billing_balance: total_credit_balance)
      consumer_billing.update!(payment_status: 1)

      # puts "🔄  請求更新: 請求ID #{consumer_billing.id}, 最新請求残高 #{total_credit_balance}, ステータス #{consumer_billing.payment_status}"
    end

    def self.update_receipt_balance(receipt)
      consumer_debt = ConsumerDebt.find_by!(receipt_id: receipt.id)

      remaining_debt_balance = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
      receipt.update!(payment_balance: remaining_debt_balance)

      # puts "🔄  入金データ更新: 入金ID #{receipt.id}, 最新支払い残高 #{remaining_debt_balance}"
    end

    def self.log_execution(batch_name)
      BatchLog.create!(
      batch_name: batch_name,
      batch_executed_at: Time.current
    )

     puts "📝  バッチ履歴更新: バッチ #{batch_name} 実行記録を保存"
    end
  end
end

