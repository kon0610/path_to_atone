require_relative '../../config/environment'

module Cron
  class NettingBatch
    def self.run
      one_hour_ago = 1.hour.ago
      receipts = Receipt.joins(:consumer_billing)
                        .where(consumer_billings: { payment_status: 0 })
                        .where.not(payment_amount: nil)

      if receipts.empty?
        puts '消し込み対象の入金データはありませんでした。'
      else
        puts "消し込み対象の入金データを#{receipts.count}件抽出しました。"
        receipts.each do |receipt|
          puts "処理中: 入金ID #{receipt.id}"

          # 入金に紐づく請求を取得
          consumer_billing = receipt.consumer_billing
          if consumer_billing.nil?
            puts "入金ID #{receipt.id} に紐づく請求が見つかりませんでした。"
          else
            puts "入金ID #{receipt.id} に紐づく請求を1件取得しました。"

            # 入金に紐づく債務を取得
            consumer_debt = ConsumerDebt.find_by(receipt_id: receipt.id)
            if consumer_debt.nil?
              puts "入金ID #{receipt.id} に紐づく債務が見つかりませんでした。"
            else
              puts "入金ID #{receipt.id} に紐づく債務を1件取得しました。"

              # 債務の取引日を取得して出力
              payment_date = receipt.payment_date
              puts "入金日: #{payment_date}"

              # 初期債務金額を取得
              remaining_debt = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
              puts "現在の債務金額: #{remaining_debt}"
            end

            # 請求に紐づく債権を取得し、取引が早い順に並び替え
            consumer_credits = ConsumerCredit.joins(:consumer_transaction)
                                             .where(consumer_billing_id: consumer_billing.id)
                                             .order('consumer_transactions.registration_datetime ASC')

            if consumer_credits.empty?
              puts "請求ID #{consumer_billing.id} に紐づく債権が見つかりませんでした。"
            else
              puts "請求ID #{consumer_billing.id} に紐づく債権を#{consumer_credits.count}件取得しました。"

              # 債権と債務を相殺
              consumer_credits.each do |credit|
                remaining_credit = credit.latest_consumer_credit || credit.initial_consumer_credit
                puts "処理中の債権ID #{credit.id}: 残額 #{remaining_credit}"

                # 相殺金額を決定
                while remaining_credit > 0 && remaining_debt > 0
                  netting_amount = [remaining_credit, remaining_debt].min
                  puts "相殺金額: #{netting_amount}"

                  # 相殺条件をチェック
                  if netting_amount <= 0
                    puts "相殺金額がゼロ以下のためループを終了します。"
                    break
                  end

                  # 相殺後、remaining_debt と remaining_credit を更新
                  remaining_debt -= netting_amount
                  remaining_credit -= netting_amount
                  # 相殺処理をconsumer_offset_eventsに保存
                  if netting_amount > 0
                    # 相殺イベントを登録
                    ConsumerOffsetEvent.create!(
                      consumer_debt_id: consumer_debt.id,
                      consumer_credit_id: credit.id,
                      offset_datetime: Time.current,
                      offset_amount: netting_amount
                    )
                    puts '相殺結果を consumer_offset_events に登録しました。'
                  end

                  # 債権または債務がゼロ以下の場合はループ終了
                  if remaining_credit <= 0 || remaining_debt <= 0
                    puts "債権または債務がゼロ以下のためループを終了します。"
                    break
                  end
                end
              end
              # 相殺後の債権データを更新
              consumer_credits.each do |credit|
                # 対応する相殺イベントを取得
                offset_event = ConsumerOffsetEvent.find_by(consumer_credit_id: credit.id)

                if offset_event
                  # 相殺金額を取得
                  offset_amount = offset_event.offset_amount

                  # 最新の債権残高を計算
                  updated_credit = credit.initial_consumer_credit - offset_amount

                  # 債権データを更新
                  credit.update!(
                    latest_consumer_credit: updated_credit,
                    netting_datetime: offset_event.offset_datetime
                  )
                  puts "債権ID #{credit.id} を更新しました: 最新残高 #{updated_credit}, 相殺日時 #{offset_event.offset_datetime}"
                else
                  puts "債権ID #{credit.id} に対応する相殺イベントが見つかりませんでした。"
                end
              end
              # 相殺後の債務データを更新
              consumer_debt = ConsumerDebt.find_by(receipt_id: receipt.id)
              if consumer_debt
                # 該当する債務に関連する全ての相殺イベントを取得
                offset_events = ConsumerOffsetEvent.where(consumer_debt_id: consumer_debt.id)

                if offset_events.exists?
                  # 全ての相殺金額を合計
                  total_offset_amount = offset_events.sum(:offset_amount)

                  # 最新の債務残高を計算
                  updated_debt = consumer_debt.initial_consumer_debt - total_offset_amount

                  # 最も新しい相殺日時を取得
                  latest_offset_datetime = offset_events.maximum(:offset_datetime)

                  # 債務データを更新
                  consumer_debt.update!(
                    latest_consumer_debt: updated_debt,
                    netting_datetime: latest_offset_datetime
                  )

                  puts "債務ID #{consumer_debt.id} を更新しました: 最新残高 #{updated_debt}, 最終相殺日時 #{latest_offset_datetime}"
                else
                  puts "債務ID #{consumer_debt.id} に関連する相殺イベントが見つかりませんでした。"
                end
              else
                puts "入金ID #{receipt.id} に紐づく債務が見つかりませんでした。"
              end
              # 請求のデータ更新処理
              ConsumerBilling.all.each do |billing|
                # 該当請求に紐づく債権の合計を計算
                total_credit_balance = billing.consumer_credits.sum(:latest_consumer_credit)
                puts "請求ID #{billing.id} に紐づく債権の合計金額: #{total_credit_balance}"

                # billing_balanceを更新
                billing.update!(billing_balance: total_credit_balance)
                puts "請求ID #{billing.id} の billing_balance を #{total_credit_balance} に更新しました。"

                # billing_balanceがゼロの場合、payment_statusを支払い済みに変更
                if total_credit_balance.zero?
                  billing.update!(payment_status: 1)
                  puts "請求ID #{billing.id} の payment_status を '1 (支払い済み)' に更新しました。"
                end
              end
              # 入金データの更新処理
              ConsumerOffsetEvent.all.each do |event|
                # 相殺イベントから債務を取得
                consumer_debt = ConsumerDebt.find_by(id: event.consumer_debt_id)
                next unless consumer_debt

                # 債務に紐づく入金を取得
                receipt = consumer_debt.receipt
                next unless receipt

                # 債務の最新残高を取得し、入金の残高 (balance) に登録
                remaining_debt_balance = consumer_debt.latest_consumer_debt || consumer_debt.initial_consumer_debt
                receipt.update!(balance: remaining_debt_balance)
                puts "入金ID #{receipt.id} の balance を #{remaining_debt_balance} に更新しました。"
              end

            end
          end
        end
      end
    rescue StandardError => e
      puts "エラーが発生しました: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end
end

Cron::NettingBatch.run
