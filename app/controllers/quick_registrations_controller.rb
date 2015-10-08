class QuickRegistrationsController < ApplicationController
  expose(:user)

  before_filter :redirect_authorized_users

  def create
    if user.update(email: params[:email])
      sign_in user
      redirect_to root_path, notice: t('.success_notice')
    else
      redirect_to new_user_registration_path, alert: user.errors.full_messages.first
    end
  end


  private

    def redirect_authorized_users
      if user_signed_in?
        redirect_to root_path, notice: "You are already signed in."
      end
    end
end
