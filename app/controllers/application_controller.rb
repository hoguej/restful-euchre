class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :ensure_session
  before_action :set_current_session

  protected

  def ensure_session
    if cookies[:session_id].blank?
      cookies.permanent[:session_id] = SecureRandom.uuid
    end
  end

  def set_current_session
    @current_session = Session.find_or_create_by(session_id: cookies[:session_id]) do |session|
      session.name = "Player #{rand(1000..9999)}" # Default name
    end
  end

  def current_session
    @current_session
  end

  def require_session_name
    if current_session.name.blank? || current_session.name.start_with?("Player")
      render json: { error: "Display name is required" }, status: :bad_request
      return false
    end
    true
  end
end 