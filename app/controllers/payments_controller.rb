class PaymentsController < ApplicationController
  def new
    @payment = Payment.new
  end

  def create
    @payment = Payment.new(payment_params)
    if @payment.save
      redirect_to payment_path(@payment), notice: '入金が完了しました。'
    else
      render :new
    end
  end

  def show
    @payment = Payment.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:amount, :payment_time)
  end

end
