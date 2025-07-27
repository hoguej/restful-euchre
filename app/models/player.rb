class Player < ApplicationRecord
  SEATS = [0, 1, 2, 3].freeze
  TEAMS = [0, 1].freeze

  belongs_to :game
  belongs_to :session
  has_many :card_plays, dependent: :destroy
  has_many :player_hands, dependent: :destroy

  validates :seat, inclusion: { in: SEATS }, allow_nil: true
  validates :team, inclusion: { in: TEAMS }, allow_nil: true
  validates :seat, uniqueness: { scope: :game_id }, allow_nil: true
  validates :session_id, uniqueness: { scope: :game_id }

  scope :by_seat, -> { order(:seat) }
  scope :team, ->(team_number) { where(team: team_number) }

  def teammate
    return nil unless team.present? && seat.present?

    game.players.find_by(team: team, seat: (seat + 2) % 4)
  end

  def opponents
    return Player.none unless team.present?

    game.players.where.not(team: team)
  end

  def hand_for_round(round)
    player_hands.find_by(round: round)
  end

  def current_hand
    return nil unless game.current_round

    hand_for_round(game.current_round)
  end
end
