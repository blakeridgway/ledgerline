class ProfilesController < ApplicationController
  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      redirect_to profile_path, notice: "Business details updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.expect(user: [
        :name, :business_name, :email_address, :phone, :address, :tax_id,
        :default_currency, :default_payment_terms_days, :invoice_prefix,
        :expected_hours_per_month, :tax_set_aside_percent, :payment_instructions
      ])
    end
end
