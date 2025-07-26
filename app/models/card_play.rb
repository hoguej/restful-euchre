class CardPlay < ApplicationRecord
  PLAY_ORDERS = [0, 1, 2, 3].freeze

  # Card format: "9H", "TC", "JD", "QS", "KH", "AS" etc.
  RANKS = %w[9 T J Q K A].freeze
  SUITS = %w[H D C S].freeze # Hearts, Diamonds, Clubs, Spades

  belongs_to :trick
  belongs_to :player

  validates :card, presence: true, format: { with: /\A[9TJQKA][HDCS]\z/ }
  validates :play_order, inclusion: { in: PLAY_ORDERS }
  validates :play_order, uniqueness: { scope: :trick_id }

  scope :in_order, -> { order(:play_order) }

  def rank
    card[0]
  end

  def suit
    card[1]
  end

  def trump?(trump_suit)
    return false unless trump_suit

    # Regular trump suit card
    return true if suit == trump_suit_letter(trump_suit)

    # Left bower (jack of same color as trump)
    return unless rank == 'J'

    case trump_suit
    when 'hearts' then suit == 'D'
    when 'diamonds' then suit == 'H'
    when 'clubs' then suit == 'S'
    when 'spades' then suit == 'C'
    end
  end

  def effective_suit(trump_suit)
    if trump?(trump_suit)
      trump_suit_letter(trump_suit)
    else
      suit
    end
  end

  private

  def trump_suit_letter(trump_suit)
    case trump_suit
    when 'hearts' then 'H'
    when 'diamonds' then 'D'
    when 'clubs' then 'C'
    when 'spades' then 'S'
    end
  end
end
