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
        # receiptsの内容を確認する
        puts "Receipts count: #{receipts.count}"
        puts "Receipts: #{receipts.inspect}"

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

          puts "入金ID #{receipt.id} に紐づく請求を1件取得しました。"

          # 入金に紐づく債務を取得
          consumer_debt = ConsumerDebt.find_by(receipt_id: receipt.id)
          if consumer_debt.nil?
            puts "入金ID #{receipt.id} に紐づく債務が見つかりませんでした。"
            next
          end

          puts "入金ID #{receipt.id} に紐づく債務を1件取得しました。"

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

          puts "請求ID #{consumer_billing.id} に紐づく債権を#{consumer_credits.count}件取得しました。"

          # 債権と債務を相殺
          consumer_credits.each do |credit|
            remaining_credit = credit.latest_consumer_credit || credit.initial_consumer_credit
            puts "処理中の債権ID #{credit.id}: 残額 #{remaining_credit}"

            # 相殺金額を決定
            while remaining_credit > 0 && remaining_debt > 0
              netting_amount = [remaining_credit, remaining_debt].min
              break if netting_amount <= 0

              puts "相殺金額: #{netting_amount}"

              # 相殺イベント登録
              ConsumerOffsetEvent.create!(
                consumer_debt_id: consumer_debt.id,
                consumer_credit_id: credit.id,
                offset_datetime: Time.current,
                offset_amount: netting_amount
              )

              puts '相殺結果を consumer_offset_events に登録しました。'

              remaining_debt -= netting_amount
              remaining_credit -= netting_amount
            end
          end

          # 債権の更新
          update_consumer_credits(consumer_credits)

          # 債務の更新
          update_consumer_debt(consumer_debt)

          # 請求の更新
          update_consumer_billing(consumer_billing)

          # 入金データの更新
          update_receipt_balance(receipt)
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
        offset_event = ConsumerOffsetEvent.find_by(consumer_credit_id: credit.id)
        next unless offset_event

        offset_amount = offset_event.offset_amount
        updated_credit = credit.initial_consumer_credit - offset_amount

        credit.update!(
          latest_consumer_credit: updated_credit,
          netting_datetime: offset_event.offset_datetime
        )

        puts "債権ID #{credit.id} を更新しました: 最新残高 #{updated_credit}, 相殺日時 #{offset_event.offset_datetime}"
      end
    end

    def self.update_consumer_debt(consumer_debt)
      offset_events = ConsumerOffsetEvent.where(consumer_debt_id: consumer_debt.id)
      return puts "債務ID #{consumer_debt.id} に関連する相殺イベントが見つかりませんでした。" unless offset_events.exists?

      total_offset_amount = offset_events.sum(:offset_amount)
      updated_debt = consumer_debt.initial_consumer_debt - total_offset_amount
      latest_offset_datetime = offset_events.maximum(:offset_datetime)

      consumer_debt.update!(
        latest_consumer_debt: updated_debt,
        netting_datetime: latest_offset_datetime
      )

      puts "債務ID #{consumer_debt.id} を更新しました: 最新残高 #{updated_debt}, 最終相殺日時 #{latest_offset_datetime}"
    end

    def self.update_consumer_billing(consumer_billing)
      total_credit_balance = consumer_billing.consumer_credits.sum(:latest_consumer_credit)
      consumer_billing.update!(billing_balance: total_credit_balance)

      puts "請求ID #{consumer_billing.id} の billing_balance を #{total_credit_balance} に更新しました。"

      if total_credit_balance.zero?
        consumer_billing.update!(payment_status: 1)
        puts "請求ID #{consumer_billing.id} の payment_status を '1 (支払い済み)' に更新しました。"
      end
    end

    def self.update_receipt_balance(receipt)
      consumer_debt = ConsumerDebt.find_by(receipt_id: receipt.id)
      return unless consumer_debt

      remaining_debt_balance = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
      receipt.update!(payment_balance: remaining_debt_balance)

      puts "入金ID #{receipt.id} の payment_balance を #{remaining_debt_balance} に更新しました。"
    end
  end
end

