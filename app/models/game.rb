class Game < ApplicationRecord
  STATES = %w[waiting active finished].freeze
  TEAMS = [0, 1].freeze

  has_many :players, dependent: :destroy
  has_many :sessions, through: :players
  has_many :rounds, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :state, inclusion: { in: STATES }
  validates :winning_team, inclusion: { in: TEAMS }, allow_nil: true

  enum :state, { waiting: 'waiting', active: 'active', finished: 'finished' }

  before_validation :generate_code, on: :create
  after_create :set_initial_state

  scope :joinable, -> { where(state: 'waiting') }

  def full?
    players.count >= 4
  end

  def can_start?
    players.count == 4 && waiting?
  end

  def start_game!
    return false unless can_start?

    assign_seats_and_teams!
    update!(state: 'active')
    create_first_round!
  end

  def current_round
    rounds.order(:number).last
  end

  def team_score(team)
    rounds.completed.sum do |round|
      # Determine who gets the points based on euchre rules
      if round.maker_team == team
        # This team made trump
        if round.winning_team == team
          # Made trump and won - get 1 or 2 points
          round.tricks_won_by_team(team) == 5 ? 2 : 1
        else
          # Made trump but lost - euchred, get 0 points
          0
        end
      elsif round.winning_team == team
        # Other team made trump
        # Other team made trump but this team won - euchre, get 2 points
        2
      else
        # Other team made trump and won - this team gets 0 points
        0
      end
    end
  end

  def winner
    TEAMS.find { |team| team_score(team) >= 10 }
  end

  def finish_game!
    winning_team = winner
    update!(state: 'finished', winning_team: winning_team) if winning_team
  end

  private

  def generate_code
    self.code ||= SecureRandom.alphanumeric(8).upcase
  end

  def set_initial_state
    self.state = 'waiting'
  end

  def assign_seats_and_teams!
    shuffled_players = players.shuffle
    shuffled_players.each_with_index do |player, index|
      player.update!(seat: index, team: index % 2)
    end
  end

  def create_first_round!
    dealer_seat = rand(4)
    # turned_up_card will be set during card dealing
    rounds.create!(number: 1, dealer_seat: dealer_seat)
  end
end
