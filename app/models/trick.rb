class Trick < ApplicationRecord
  SEATS = [0, 1, 2, 3].freeze
  TRICK_NUMBERS = [0, 1, 2, 3, 4].freeze

  belongs_to :round
  has_many :card_plays, dependent: :destroy
  has_many :players, through: :card_plays

  validates :number, inclusion: { in: TRICK_NUMBERS }
  validates :lead_seat, inclusion: { in: SEATS }
  validates :winning_seat, inclusion: { in: SEATS }, allow_nil: true
  validates :number, uniqueness: { scope: :round_id }
  validate :first_trick_led_by_player_left_of_dealer

  scope :completed, -> { where.not(winning_seat: nil) }

  def completed?
    card_plays.count == 4 && winning_seat.present?
  end

  def current_turn_seat
    return nil if completed?

    if card_plays.empty?
      lead_seat
    else
      play_order = card_plays.count
      (lead_seat + play_order) % 4
    end
  end

  def can_play_card?(seat)
    current_turn_seat == seat && !completed?
  end

  def play_card!(player, card)
    return false unless can_play_card?(player.seat)
    return false unless valid_play?(player, card)

    play_order = card_plays.count
    card_plays.create!(
      player: player,
      card: card,
      play_order: play_order
    )

    determine_winner! if card_plays.count == 4

    true
  end

  def determine_winner!
    return if card_plays.count != 4

    trump_suit = round.trump_suit
    lead_suit = lead_card_suit

    winning_play = card_plays.max_by do |play|
      card_value(play.card, trump_suit, lead_suit)
    end

    update!(winning_seat: winning_play.player.seat)
  end

  private

  def valid_play?(_player, _card)
    # Basic validation - player has the card and follows suit if possible
    # This would be expanded with proper hand tracking
    true
  end

  def lead_card_suit
    return nil if card_plays.empty?

    card_plays.find_by(play_order: 0).card[1] # Second character is suit
  end

  def card_value(card, trump_suit, lead_suit)
    rank = card[0]
    suit = card[1]
    trump_letter = trump_suit_letter(trump_suit)
    lead_letter = lead_suit # lead_suit is already a letter

    # Euchre card ranking with trump and jacks
    if trump_letter == suit
      case rank
      when 'J' then 100 # Right bower (jack of trump)
      when 'A' then 90
      when 'K' then 80
      when 'Q' then 70
      when 'T' then 60  # T = 10
      when '9' then 50
      end
    elsif jack_of_same_color?(card, trump_suit)
      99 # Left bower (jack of same color as trump)
    elsif suit == lead_letter
      case rank
      when 'A' then 40
      when 'K' then 30
      when 'Q' then 20
      when 'J' then 15
      when 'T' then 10 # T = 10
      when '9' then 5
      end
    else
      0 # Off-suit, non-trump
    end
  end

  def trump_suit_letter(trump_suit)
    case trump_suit
    when 'hearts' then 'H'
    when 'diamonds' then 'D'
    when 'clubs' then 'C'
    when 'spades' then 'S'
    end
  end

  def jack_of_same_color?(card, trump_suit)
    return false unless card[0] == 'J'

    suit = card[1]
    trump_letter = trump_suit_letter(trump_suit)
    case trump_letter
    when 'H' then suit == 'D' # Hearts trump, diamond jack is left bower
    when 'D' then suit == 'H' # Diamonds trump, heart jack is left bower
    when 'C' then suit == 'S' # Clubs trump, spade jack is left bower
    when 'S' then suit == 'C' # Spades trump, club jack is left bower
    else false
    end
  end

  def first_trick_led_by_player_left_of_dealer
    return unless number == 0 # Only validate first trick
    return unless round.present? # Need round to get dealer_seat

    expected_lead_seat = (round.dealer_seat + 1) % 4
    return if lead_seat == expected_lead_seat

    errors.add(:lead_seat, "First trick must be led by player to the left of dealer (seat #{expected_lead_seat})")
  end
end
