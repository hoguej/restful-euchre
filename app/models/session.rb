class Session < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :games, through: :players

  validates :session_id, presence: true, uniqueness: true
  validates :name, presence: true

  before_validation :generate_session_id, on: :create

  private

  def generate_session_id
    return if Rails.env.test? && session_id.present? # Don't override in tests if already set

    self.session_id ||= SecureRandom.uuid
  end
end
