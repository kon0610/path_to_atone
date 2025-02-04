require_relative '../../config/environment'

module Cron
  class NettingBatch
    def self.run
      begin
        # バッチログから最新の実行時間を取得
        last_batch_executed_at = BatchLog.where(batch_name: 'NettingBatch').order(batch_executed_at: :desc).pluck(:batch_executed_at).first
        puts "最終実行時間: #{last_batch_executed_at}"

        receipts = Receipt.joins(:consumer_billing)
                          .joins(:consumer_debt)
                          .where(consumer_billings: { payment_status: 0 })
                          .where.not(payment_amount: nil)
                          .where(
                    "consumer_debts.netting_datetime IS NULL OR consumer_debts.netting_datetime > ?",
                    last_batch_executed_at|| Time.at(0)
                  )

        if receipts.empty?
          puts '消し込み対象の入金データはありませんでした。'
          return
        end
        puts "消し込み対象の入金データを#{receipts.count}件抽出しました。"

        receipts.each do |receipt|
          puts "処理中: 入金ID #{receipt.id}"

          # 入金に紐づく請求を取得
          consumer_billing = receipt.consumer_billing
          if consumer_billing.nil?
            puts "入金ID #{receipt.id} に紐づく請求が見つかりませんでした。"
            next
          end

          # 入金に紐づく債務を取得
          consumer_debt = ConsumerDebt.find_by(receipt_id: receipt.id)
          if consumer_debt.nil?
            puts "入金ID #{receipt.id} に紐づく債務が見つかりませんでした。"
            next
          end

          # 債務の取引日を出力
          payment_date = receipt.payment_date
          puts "入金日: #{payment_date}"

          # 初期債務金額を取得
          remaining_debt = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
          puts "現在の債務金額: #{remaining_debt}"

          # 請求に紐づく債権を取得し、取引が早い順に並び替え
          consumer_credits = ConsumerCredit.joins(:consumer_transaction)
                                            .where(consumer_billing_id: consumer_billing.id)
                                            .order('consumer_transactions.registration_datetime ASC')

          if consumer_credits.empty?
            puts "請求ID #{consumer_billing.id} に紐づく債権が見つかりませんでした。"
            next
          end

          # 債権と債務を相殺
          consumer_credits.each do |credit|
            break if credit.initial_consumer_credit == 0

            # 相殺イベント登録
            ConsumerOffsetEvent.create!(
              consumer_debt_id: consumer_debt.id,
              consumer_credit_id: credit.id,
              offset_datetime: Time.current,
              offset_amount: credit.initial_consumer_credit,
            )
          end

          # 債権の更新
          update_consumer_credits(consumer_credits)

          # 債務の更新
          update_consumer_debt(consumer_debt)

          # 請求の更新
          update_consumer_billing(consumer_billing)

          # 入金データの更新
          update_receipt_balance(receipt)

          # バッチ履歴の更新
          log_execution('NettingBatch')

        end
        puts "消し込み完了しました"
      rescue StandardError => e
        Rails.logger.error "エラーが発生しました: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
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
    end

    def self.update_consumer_billing(consumer_billing)
      total_credit_balance = consumer_billing.consumer_credits.sum(:latest_consumer_credit)
      consumer_billing.update!(billing_balance: total_credit_balance)

      if total_credit_balance.zero?
        consumer_billing.update!(payment_status: 1)
      end
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

