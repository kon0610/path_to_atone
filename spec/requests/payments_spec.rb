require 'rails_helper'

RSpec.describe "Payments", type: :request do
  let(:valid_attributes) { { amount: 1000 } }
  describe "POST /payments" do
    context "リクエストが正しい場合" do
      it "新しい入金が作成される" do
        expect {
          post payments_path, params: { payment: valid_attributes }
        }.to change(Payment, :count).by(1)
      end

      it "入金データが正しくデータベースに保存される" do
        post payments_path, params: { payment: valid_attributes }
        payment = Payment.last
        expect(payment.amount).to eq(1000)
        expect(payment.payment_time).to be_within(1.second).of(Time.current)
      end

      it "入金後、入金完了画面にリダイレクトされる" do
        post payments_path, params: { payment: valid_attributes }
        payment = Payment.last
        expect(response).to redirect_to(payment_path(payment))
      end
    end
  end
end
