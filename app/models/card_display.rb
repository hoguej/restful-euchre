class CardDisplay
  # Unicode suit symbols
  SUIT_SYMBOLS = {
    'H' => '♥',  # Hearts
    'D' => '♦',  # Diamonds
    'C' => '♣',  # Clubs
    'S' => '♠'   # Spades
  }.freeze

  # Reverse mapping from symbols to letters (for internal storage)
  SYMBOL_TO_LETTER = SUIT_SYMBOLS.invert.freeze

  # ANSI color codes for terminal display
  # Black text on white background for spades/clubs
  # Red text on white background for hearts/diamonds
  SUIT_COLORS = {
    '♠' => "\e[30;47m",  # Black on white
    '♣' => "\e[30;47m",  # Black on white
    '♥' => "\e[31;47m",  # Red on white
    '♦' => "\e[31;47m"   # Red on white
  }.freeze

  RESET_COLOR = "\e[0m".freeze

  class << self
    # Convert letter-based suit to Unicode symbol
    def suit_symbol(suit_letter)
      SUIT_SYMBOLS[suit_letter] || suit_letter
    end

    # Convert Unicode symbol back to letter
    def suit_letter(suit_symbol)
      SYMBOL_TO_LETTER[suit_symbol] || suit_symbol
    end

    # Format a card with Unicode suit and terminal colors
    def format_card(card, with_color: false)
      return card if card.nil? || card.length != 2

      rank = card[0]
      suit_letter = card[1]
      suit_symbol = suit_symbol(suit_letter)

      formatted_card = "#{rank}#{suit_symbol}"

      if with_color
        color_code = SUIT_COLORS[suit_symbol]
        "#{color_code}#{formatted_card}#{RESET_COLOR}"
      else
        formatted_card
      end
    end

    # Format multiple cards
    def format_cards(cards, with_color: false)
      return [] if cards.nil?

      cards.map { |card| format_card(card, with_color: with_color) }
    end

    # Convert suit name to Unicode symbol
    def suit_name_to_symbol(suit_name)
      case suit_name
      when 'hearts' then '♥'
      when 'diamonds' then '♦'
      when 'clubs' then '♣'
      when 'spades' then '♠'
      else suit_name
      end
    end

    # Convert Unicode symbol to suit name
    def suit_symbol_to_name(suit_symbol)
      case suit_symbol
      when '♥' then 'hearts'
      when '♦' then 'diamonds'
      when '♣' then 'clubs'
      when '♠' then 'spades'
      else suit_symbol
      end
    end

    # Format trump suit announcement with color
    def format_trump_announcement(trump_suit, with_color: false)
      symbol = suit_name_to_symbol(trump_suit)
      formatted = "#{trump_suit.upcase} (#{symbol})"

      if with_color
        color_code = SUIT_COLORS[symbol]
        "#{color_code}#{formatted}#{RESET_COLOR}"
      else
        formatted
      end
    end
  end
end
