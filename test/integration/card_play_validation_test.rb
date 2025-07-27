require 'test_helper'

class CardPlayValidationTest < ActionDispatch::IntegrationTest
  test 'CardPlay validates card format' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 0, turned_up_card: generate_test_card)
    trick = round.tricks.create!(number: 0, lead_seat: 1)
    session = Session.create!(name: 'Player1')
    player = game.players.create!(session: session)

    # Valid card
    card_play = trick.card_plays.build(player: player, card: '9H', play_order: 0)
    assert card_play.valid?

    # Invalid format
    card_play = trick.card_plays.build(player: player, card: 'invalid', play_order: 0)
    assert_not card_play.valid?

    card_play = trick.card_plays.build(player: player, card: '9X', play_order: 0)
    assert_not card_play.valid?
  end

  test 'CardPlay determines trump correctly' do
    # Test right bower (Jack of trump suit)
    card_play = CardPlay.new(card: 'JH')
    assert card_play.trump?('hearts')
    assert_not card_play.trump?('spades')

    # Test left bower (Jack of same color as trump)
    card_play = CardPlay.new(card: 'JD')
    assert card_play.trump?('hearts') # Diamond jack is left bower when hearts is trump
    assert card_play.trump?('diamonds') # Also trump when diamonds is trump (right bower)

    # Test other color J is not trump
    card_play = CardPlay.new(card: 'JS')
    assert card_play.trump?('spades')
    assert_not card_play.trump?('hearts')
    assert_not card_play.trump?('diamonds')

    # Test regular trump
    card_play = CardPlay.new(card: '9H')
    assert card_play.trump?('hearts')
    assert_not card_play.trump?('spades')

    # Test clubs/spades left bower relationship
    card_play = CardPlay.new(card: 'JS')
    assert card_play.trump?('clubs') # Spade jack is left bower when clubs is trump
    assert card_play.trump?('spades') # Also trump when spades is trump (right bower)
  end
end
