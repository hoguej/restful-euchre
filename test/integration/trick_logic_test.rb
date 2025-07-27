require 'test_helper'

class TrickLogicTest < ActionDispatch::IntegrationTest
  test 'Trick determines current turn correctly' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 0, turned_up_card: generate_test_card)
    trick = round.tricks.create!(number: 0, lead_seat: 1)

    # First player's turn
    assert_equal 1, trick.current_turn_seat

    # Add first card play
    player = game.players.create!(session: Session.create!(name: 'Player1'))
    trick.card_plays.create!(player: player, card: '9H', play_order: 0)

    # Should be next player's turn
    assert_equal 2, trick.current_turn_seat
  end

  test 'Trick determines winner with trump cards' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 0, turned_up_card: generate_test_card, trump_suit: 'hearts')
    trick = round.tricks.create!(number: 0, lead_seat: 1)

    # Create players
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session, seat: i)
    end

    # Play cards in correct order starting from lead_seat (1)
    # Seat 1: 9S, Seat 2: JH (right bower), Seat 3: TS, Seat 0: KS
    cards = %w[9S JH TS KS]
    cards.each_with_index do |card, i|
      seat = (trick.lead_seat + i) % 4
      player = players.find { |p| p.seat == seat }
      trick.card_plays.create!(player: player, card: card, play_order: i)
    end

    # Determine winner
    trick.determine_winner!

    # Player at seat 2 played JH (right bower) and should win
    assert_equal 2, trick.winning_seat
  end

  test 'Trick determines winner with left bower' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 0, turned_up_card: generate_test_card, trump_suit: 'hearts')
    trick = round.tricks.create!(number: 0, lead_seat: 1)

    # Create players
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session, seat: i)
    end

    # Play cards in correct order starting from lead_seat (1)
    # Seat 1: 9S, Seat 2: JD (left bower), Seat 3: TS, Seat 0: KS
    cards = %w[9S JD TS KS]
    cards.each_with_index do |card, i|
      seat = (trick.lead_seat + i) % 4
      player = players.find { |p| p.seat == seat }
      trick.card_plays.create!(player: player, card: card, play_order: i)
    end

    trick.determine_winner!

    # Player at seat 2 played JD (left bower) and should win
    assert_equal 2, trick.winning_seat
  end

  test 'Trick determines winner following suit' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 0, turned_up_card: generate_test_card, trump_suit: 'hearts')
    trick = round.tricks.create!(number: 0, lead_seat: 1)

    # Create players
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session, seat: i)
    end

    # Play cards in correct order starting from lead_seat (1)
    # Seat 1: 9S, Seat 2: AS, Seat 3: TS, Seat 0: KS (no trump, ace high)
    cards = %w[9S AS TS KS]
    cards.each_with_index do |card, i|
      seat = (trick.lead_seat + i) % 4
      player = players.find { |p| p.seat == seat }
      trick.card_plays.create!(player: player, card: card, play_order: i)
    end

    trick.determine_winner!

    # Player at seat 2 played AS (ace of spades) and should win
    assert_equal 2, trick.winning_seat
  end

  test 'First trick must be led by player to left of dealer' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: generate_test_card)

    # Valid first trick: dealer is seat 2, so lead should be seat 3
    valid_trick = round.tricks.build(number: 0, lead_seat: 3)
    assert valid_trick.valid?

    # Invalid first trick: dealer is seat 2, but lead is seat 1 (should be 3)
    invalid_trick = round.tricks.build(number: 0, lead_seat: 1)
    assert_not invalid_trick.valid?
    assert_includes invalid_trick.errors[:lead_seat], 'First trick must be led by player to the left of dealer (seat 3)'
  end
end
