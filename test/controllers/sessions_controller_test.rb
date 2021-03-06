require 'test_helper'

class SessionsControllerTest < ActionController::TestCase

  tests Clearance::SessionsController

  should_filter_params :password

  context "on GET to /sessions/new without a request return url" do
    setup { get :new }

    should_respond_with    :success
    should_render_template :new
    should_not_set_the_flash
    should_display_a_sign_in_form {nil}  # no return_url
  end

  context "on GET to /sessions/new with a request return url" do
    setup do
      @return_url = "/url_in_the_request"
      get :new, :return_to => @return_url
    end
    
    should_respond_with    :success
    should_render_template :new
    should_not_set_the_flash
    should_display_a_sign_in_form {@return_url}
  end

  context "on POST to #create with unconfirmed credentials" do
    setup do
      @user = Factory(:user)
      ActionMailer::Base.deliveries.clear
      post :create, :session => {
                      :email    => @user.email,
                      :password => @user.password }
    end

    should_deny_access(:flash => /User has not confirmed email. Confirmation email will be resent./i)

    should "send the confirmation email" do
      assert_not_nil email = ActionMailer::Base.deliveries[0]
      assert_match /account confirmation/i, email.subject
    end
  end

  context "on POST to #create with good credentials" do
    setup do
      @user = Factory(:email_confirmed_user)
      @user.update_attribute(:remember_token, "old-token")
      post :create, :session => {
                      :email    => @user.email,
                      :password => @user.password }
    end

    should_set_the_flash_to /signed in/i
    should_redirect_to_url_after_create
    should_set_cookie("remember_token", "old-token", 1.year.from_now)

    should "not change the remember token" do
      assert_equal "old-token", @user.reload.remember_token
    end
  end

  context "on POST to #create with good credentials, and remember_token expiration overridden" do
    setup do
      @user = Factory(:email_confirmed_user)
      @user.update_attribute(:remember_token, "old-token-2")
      class << @controller
        def remember_token_expires_at
          5.days.from_now
        end
      end
      post :create, :session => {
                      :email    => @user.email,
                      :password => @user.password }
    end

    should_set_cookie("remember_token", "old-token-2", 5.days.from_now)
  end

  context "on POST to #create with good credentials, and remember_token in session cookie" do
    setup do
      @user = Factory(:email_confirmed_user)
      @user.update_attribute(:remember_token, "old-token-3")
      class << @controller
        def remember_token_expires_at
          nil  # should prevent any expiration date from being set in cookie
        end
      end
      post :create, :session => {
                      :email    => @user.email,
                      :password => @user.password }
    end

    should_set_cookie("remember_token", "old-token-3", nil)
  end

  context "on POST to #create with good credentials and a session return url" do
    setup do
      @user = Factory(:email_confirmed_user)
      @return_url = '/url_in_the_session'
      @request.session[:return_to] = @return_url
      post :create, :session => {
                      :email    => @user.email,
                      :password => @user.password }
    end

    should_redirect_to("the return URL") { @return_url }
  end

  context "on POST to #create with good credentials and a request return url" do
    setup do
      @user = Factory(:email_confirmed_user)
      @return_url = '/url_in_the_request'
      post :create, :session => {
                      :email     => @user.email,
                      :password  => @user.password },
                      :return_to => @return_url
    end

    should_redirect_to("the return URL") { @return_url }
  end

  context "on POST to #create with good credentials and a session return url and request return url" do
    setup do
      @user = Factory(:email_confirmed_user)
      @return_url = '/url_in_the_session'
      @request.session[:return_to] = @return_url
      post :create, :session => {
                      :email     => @user.email,
                      :password  => @user.password },
                      :return_to => '/url_in_the_request'
    end

    should_redirect_to("the return URL") { @return_url }
  end

  context "on POST to #create with bad credentials" do
    setup do
      post :create, :session => {
                      :email       => 'bad.email@example.com',
                      :password    => "bad value" }
    end

    should_set_the_flash_to /bad/i
    should_respond_with    :unauthorized
    should_render_template :new
    should_not_be_signed_in

    should 'not create the cookie' do
      assert_nil cookies['remember_token']
    end
  end

  context "on DELETE to #destroy given a signed out user" do
    setup do
      sign_out
      delete :destroy
    end
    should_set_the_flash_to(/signed out/i)
    should_redirect_to_url_after_destroy
  end

  context "on DELETE to #destroy with a cookie" do
    setup do
      @user = Factory(:email_confirmed_user)
      @user.update_attribute(:remember_token, "old-token")
      @request.cookies["remember_token"] = "old-token"
      delete :destroy
    end

    should_set_the_flash_to(/signed out/i)
    should_redirect_to_url_after_destroy

    should "delete the cookie token" do
      assert_nil cookies['remember_token']
    end

    should "reset the remember token" do
      assert_not_equal "old-token", @user.reload.remember_token
    end

    should "unset the current user" do
      assert_nil @controller.current_user
    end
  end

  context "on DELETE to #destroy given a signed out user with a request return url" do
    setup do
      sign_out
      @return_url = '/url_in_the_request'
      delete :destroy, :return_to => @return_url
    end
    should_set_the_flash_to(/signed out/i)
    should_redirect_to("the return URL") { @return_url }
  end

  context "on DELETE to #destroy with a cookie and a request return url" do
    setup do
      @user = Factory(:email_confirmed_user)
      @user.update_attribute(:remember_token, "old-token")
      @request.cookies["remember_token"] = "old-token"
      @return_url = '/url_in_the_request'
      delete :destroy, :return_to => @return_url
    end

    should_set_the_flash_to(/signed out/i)
    should_redirect_to("the return URL") { @return_url }

    should "delete the cookie token" do
      assert_nil cookies['remember_token']
    end

    should "reset the remember token" do
      assert_not_equal "old-token", @user.reload.remember_token
    end
  end

end
