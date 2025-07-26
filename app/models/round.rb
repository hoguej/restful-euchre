class Round < ApplicationRecord
  SUITS = %w[hearts clubs diamonds spades].freeze
  DEALER_SEATS = [0, 1, 2, 3].freeze
  TEAMS = [0, 1].freeze
  TRUMP_SELECTION_PHASES = %w[ordering_up calling_trump trump_selected].freeze

  belongs_to :game
  has_many :tricks, dependent: :destroy
  has_many :card_plays, through: :tricks

  validates :number, presence: true, uniqueness: { scope: :game_id }
  validates :dealer_seat, inclusion: { in: DEALER_SEATS }
  validates :trump_suit, inclusion: { in: SUITS }, allow_nil: true
  validates :maker_team, inclusion: { in: TEAMS }, allow_nil: true
  validates :winning_team, inclusion: { in: TEAMS }, allow_nil: true
  validates :turned_up_card, presence: true, length: { is: 2 }
  validates :trump_selection_phase, inclusion: { in: TRUMP_SELECTION_PHASES }
  validates :current_bidder_seat, inclusion: { in: DEALER_SEATS }, allow_nil: true

  enum :trump_selection_phase,
       { ordering_up: 'ordering_up', calling_trump: 'calling_trump', trump_selected: 'trump_selected' }

  after_save :check_game_end_condition, if: :saved_change_to_winning_team?
  after_create :set_initial_bidder

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

    # Generate a turned up card for the new round
    turned_up_card = generate_turned_up_card

    game.rounds.create!(
      number: number + 1,
      dealer_seat: next_dealer_seat,
      turned_up_card: turned_up_card
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

  # Trump selection methods
  def trump_selection_complete?
    trump_selected?
  end

  def can_order_up?(player_seat)
    ordering_up? && current_bidder_seat == player_seat
  end

  def can_call_trump?(player_seat)
    calling_trump? && current_bidder_seat == player_seat
  end

  def order_up!(player_seat)
    return false unless can_order_up?(player_seat)

    team = player_seat % 2
    suit = turned_up_card_suit

    update!(
      trump_suit: suit,
      maker_team: team,
      ordered_up: true,
      trump_selection_phase: 'trump_selected',
      current_bidder_seat: nil
    )

    true
  end

  def call_trump!(player_seat, suit)
    return false unless can_call_trump?(player_seat)
    return false if suit == turned_up_card_suit # Can't call same suit as turned up card
    return false unless SUITS.include?(suit)

    team = player_seat % 2

    update!(
      trump_suit: suit,
      maker_team: team,
      trump_selection_phase: 'trump_selected',
      current_bidder_seat: nil
    )

    true
  end

  def pass_bidding!(player_seat)
    return false unless current_bidder_seat == player_seat
    return false if trump_selected?

    next_bidder = next_bidder_seat

    if next_bidder.nil?
      # Everyone has passed this phase
      if ordering_up?
        # Move to calling trump phase
        update!(
          trump_selection_phase: 'calling_trump',
          current_bidder_seat: (dealer_seat + 1) % 4
        )
      else
        # Everyone passed calling trump too - throw in hand
        throw_in_hand!
      end
    else
      update!(current_bidder_seat: next_bidder)
    end

    true
  end

  def throw_in_hand!
    # No score, just create next round
    create_next_round! unless game.finished?
  end

  def turned_up_card_suit
    return nil unless turned_up_card

    case turned_up_card[1]
    when 'H' then 'hearts'
    when 'D' then 'diamonds'
    when 'C' then 'clubs'
    when 'S' then 'spades'
    end
  end

  def dealer_needs_to_discard?
    ordered_up? && trump_selected?
  end

  def start_tricks!
    return false unless trump_selected?

    # Create the first trick
    tricks.create!(
      number: 0,
      lead_seat: (dealer_seat + 1) % 4
    )

    true
  end

  private

  def set_initial_bidder
    # First bidder is to the left of the dealer
    self.current_bidder_seat = (dealer_seat + 1) % 4
    save!
  end

  def generate_turned_up_card
    # Generate a random card for the turned up card
    ranks = %w[9 T J Q K A]
    suits = %w[H D C S]
    "#{ranks.sample}#{suits.sample}"
  end

  def next_bidder_seat
    return nil unless current_bidder_seat

    # Calculate the next seat in clockwise order
    next_seat = (current_bidder_seat + 1) % 4

    # Check if we've completed a full round (all 4 players have had a turn)
    # Starting player is always to the left of dealer: (dealer_seat + 1) % 4
    starting_player = (dealer_seat + 1) % 4

    # We've completed the round when the current bidder is the dealer
    # and the next seat would be the starting player again
    if current_bidder_seat == dealer_seat && next_seat == starting_player
      return nil # Everyone has had their turn
    end

    next_seat
  end

  def check_game_end_condition
    return unless completed? # Only check when round is actually completed
    return if game.finished? # Don't check if game is already finished

    # Check if either team has reached 10 points
    return unless game.team_score(0) >= 10 || game.team_score(1) >= 10

    game.finish_game!
  end

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
