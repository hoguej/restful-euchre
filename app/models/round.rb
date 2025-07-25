class Round < ApplicationRecord
  SUITS = %w[hearts clubs diamonds spades].freeze
  DEALER_SEATS = [0, 1, 2, 3].freeze
  TEAMS = [0, 1].freeze

  belongs_to :game
  has_many :tricks, dependent: :destroy
  has_many :card_plays, through: :tricks

  validates :number, presence: true, uniqueness: { scope: :game_id }
  validates :dealer_seat, inclusion: { in: DEALER_SEATS }
  validates :trump_suit, inclusion: { in: SUITS }, allow_nil: true
  validates :maker_team, inclusion: { in: TEAMS }, allow_nil: true
  validates :winning_team, inclusion: { in: TEAMS }, allow_nil: true

  scope :completed, -> { where.not(winning_team: nil) }

  def completed?
    winning_team.present?
  end

  def current_trick
    tricks.order(:number).last
  end

  def tricks_won_by_team(team)
    tricks.select { |trick| trick.winning_seat % 2 == team }.count
  end

  def euchred?
    return false unless completed?
    maker_team != winning_team
  end

  def sweep?
    return false unless completed?
    tricks_won_by_team(winning_team) == 5
  end

  def points_scored
    return 0 unless completed?
    
    if euchred?
      2 # Defending team gets 2 points for euchre
    elsif sweep? && loner?
      4 # Loner sweep gets 4 points
    elsif sweep?
      2 # Regular sweep gets 2 points
    else
      1 # Made trump with 3-4 tricks gets 1 point
    end
  end

  def next_dealer_seat
    (dealer_seat + 1) % 4
  end

  def create_next_round!
    return nil if game.finished?
    
    game.rounds.create!(
      number: number + 1,
      dealer_seat: next_dealer_seat
    )
  end

  def complete_round!
    winning_team = determine_winning_team
    update!(winning_team: winning_team)
    
    # Update game score and check for game end
    if game.team_score(0) >= 10 || game.team_score(1) >= 10
      game.finish_game!
    else
      create_next_round!
    end
  end

  private

  def determine_winning_team
    team_0_tricks = tricks_won_by_team(0)
    team_1_tricks = tricks_won_by_team(1)
    
    if team_0_tricks > team_1_tricks
      0
    else
      1
    end
  end
end 