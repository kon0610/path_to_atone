class PaymentsController < ApplicationController
  def new
    @payment = Payment.new
  end

  def create
    @payment = Payment.new(payment_params)
    @payment.payment_time = Time.current  # 現在時刻を設定
    if @payment.save
      redirect_to payment_path(@payment), notice: '入金が完了しました。'
    else
      render :new, alert: '入金に失敗しました。もう一度お試しください。'
    end
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:amount, :payment_time)
  end

end
