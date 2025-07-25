class Session < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :games, through: :players

  validates :session_id, presence: true, uniqueness: true
  validates :name, presence: true

  before_validation :generate_session_id, on: :create

  private

  def generate_session_id
    self.session_id ||= SecureRandom.uuid
  end
end 