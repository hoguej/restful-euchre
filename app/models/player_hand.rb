class PlayerHand < ApplicationRecord
  belongs_to :player
  belongs_to :round

  # NOTE: cards can be empty when all cards have been played, so no presence validation
  validates :player_id, uniqueness: { scope: :round_id }

  # Serialize cards as JSON array
  serialize :cards, type: Array, coder: JSON

  # Card management methods
  def has_card?(card)
    cards.include?(card)
  end

  def remove_card!(card)
    return false unless has_card?(card)

    new_cards = cards.dup
    new_cards.delete_at(new_cards.index(card))
    update!(cards: new_cards)
    true
  end

  def add_card!(card)
    new_cards = cards.dup
    new_cards << card
    update!(cards: new_cards)
  end

  def card_count
    cards.length
  end

  def empty?
    cards.empty?
  end

  # Check if player has cards of a specific suit
  def has_suit?(suit_letter)
    cards.any? { |card| card[1] == suit_letter }
  end

  # Get cards of a specific suit
  def cards_of_suit(suit_letter)
    cards.select { |card| card[1] == suit_letter }
  end

  # Check if a card play follows suit rules
  def valid_play?(card, lead_suit_letter)
    return false unless has_card?(card)

    # If no lead suit (first card of trick), any card is valid
    return true if lead_suit_letter.nil?

    played_suit = card[1]

    # If playing the lead suit, always valid
    return true if played_suit == lead_suit_letter

    # If not playing lead suit, must not have any cards of lead suit
    !has_suit?(lead_suit_letter)
  end
end
