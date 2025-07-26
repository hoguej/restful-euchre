require 'test_helper'

class GameLogicTest < ActionDispatch::IntegrationTest
  # === GAME MODEL TESTS ===

  test 'Game generates unique codes' do
    game1 = Game.create!
    game2 = Game.create!

    assert_not_equal game1.code, game2.code
    assert game1.code.length == 8
    assert game2.code.length == 8
  end

  test 'Game starts in waiting state' do
    game = Game.create!
    assert_equal 'waiting', game.state
    assert_nil game.winning_team
  end

  test "Game knows when it's full" do
    game = Game.create!
    assert_not game.full?

    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      game.players.create!(session: session)
    end

    assert game.full?
  end

  test 'Game can start when 4 players join' do
    game = Game.create!

    # Add 3 players - can't start yet
    3.times do |i|
      session = Session.create!(name: "Player#{i}")
      game.players.create!(session: session)
    end
    assert_not game.can_start?

    # Add 4th player - now can start
    session = Session.create!(name: 'Player4')
    game.players.create!(session: session)
    assert game.can_start?
  end

  test 'Game assigns seats and teams when started' do
    game = Game.create!

    # Add 4 players
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session)
    end

    # Start game
    game.start_game!

    # Reload players to get updated attributes
    players.each(&:reload)

    # Check seats are assigned (0-3)
    seats = players.map(&:seat).sort
    assert_equal [0, 1, 2, 3], seats

    # Check teams are assigned (seats 0&2 vs 1&3)
    player_by_seat = players.index_by(&:seat)
    assert_equal player_by_seat[0].team, player_by_seat[2].team
    assert_equal player_by_seat[1].team, player_by_seat[3].team
    assert_not_equal player_by_seat[0].team, player_by_seat[1].team
  end

  test 'Game creates first round when started' do
    game = Game.create!

    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      game.players.create!(session: session)
    end

    game.start_game!

    assert_equal 'active', game.state
    assert_equal 1, game.rounds.count

    round = game.current_round
    assert_equal 1, round.number
    assert_includes [0, 1, 2, 3], round.dealer_seat
  end

  # === SCORING TESTS ===

  test 'Game calculates team scores correctly' do
    game = Game.create!

    # Create a completed round where team 0 won
    game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      maker_team: 0,
      loner: false,
      winning_team: 0
    )

    assert_equal 1, game.team_score(0)
    assert_equal 0, game.team_score(1)
  end

  test 'Game awards 2 points for euchre' do
    game = Game.create!

    # Round where team 0 called trump but team 1 won (euchre)
    game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      maker_team: 0,
      loner: false,
      winning_team: 1
    )

    # Team 1 should get points for euchring team 0
    # When the opposing team wins, they get 2 points for euchre
    assert_equal 0, game.team_score(0)
    assert_equal 2, game.team_score(1)
  end

  test 'Game automatically finishes when team reaches 10 points' do
    game = Game.create!
    game.update!(state: 'active') # Set to active state for testing

    # Create enough rounds for team 0 to reach 10 points
    10.times do |i|
      round = game.rounds.create!(
        number: i + 1,
        dealer_seat: 0,
        turned_up_card: generate_test_card,
        trump_suit: 'hearts',
        trump_selection_phase: 'trump_selected',
        maker_team: 0,
        loner: false
      )
      # Mark the round as completed with team 0 winning
      round.update!(winning_team: 0)
    end

    # Game should automatically be finished after 10th round
    game.reload
    assert_equal 'finished', game.state
    assert_equal 0, game.winning_team
    assert_equal 0, game.winner
  end

  test 'Game does not finish before reaching 10 points' do
    game = Game.create!
    game.update!(state: 'active') # Set to active state for testing

    # Create 9 rounds for team 0 (not quite 10 points yet)
    9.times do |i|
      round = game.rounds.create!(
        number: i + 1,
        dealer_seat: 0,
        turned_up_card: generate_test_card,
        trump_suit: 'hearts',
        trump_selection_phase: 'trump_selected',
        maker_team: 0,
        loner: false
      )
      # Mark the round as completed with team 0 winning
      round.update!(winning_team: 0)
    end

    # Game should still be active
    game.reload
    assert_equal 'active', game.state
    assert_nil game.winning_team
    assert_equal 9, game.team_score(0)
  end

  # === ROUND LOGIC TESTS ===

  test 'Round tracks dealer progression' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 1, turned_up_card: generate_test_card)

    assert_equal 2, round.next_dealer_seat

    # Test wrapping around
    round.dealer_seat = 3
    assert_equal 0, round.next_dealer_seat
  end

  test 'Round creates next round correctly' do
    game = Game.create!
    first_round = game.rounds.create!(
      number: 1,
      dealer_seat: 1,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      maker_team: 0,
      winning_team: 0
    )

    next_round = first_round.create_next_round!

    assert_not_nil next_round
    assert_equal 2, next_round.number
    assert_equal 2, next_round.dealer_seat
  end

  # === TRICK LOGIC TESTS ===

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

  # === TRUMP SELECTION TESTS ===

  test 'Round starts in ordering_up phase with correct bidder' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: 'JH')

    assert_equal 'ordering_up', round.trump_selection_phase
    assert_equal 3, round.current_bidder_seat # Left of dealer (2)
    assert_nil round.trump_suit
    assert_nil round.maker_team
    assert_not round.ordered_up
  end

  test 'Player can order up the turned card' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: 'JH')

    # Player to left of dealer (seat 3) orders up
    assert round.can_order_up?(3)
    assert_not round.can_order_up?(0) # Not their turn

    result = round.order_up!(3)
    assert result

    # Check the results
    assert_equal 'trump_selected', round.trump_selection_phase
    assert_equal 'hearts', round.trump_suit
    assert_equal 1, round.maker_team # Seat 3 is team 1 (3 % 2 = 1)
    assert round.ordered_up
    assert_nil round.current_bidder_seat
  end

  test 'Passing moves to next bidder in ordering_up phase' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: 'JH')

    # Player 3 passes
    assert round.pass_bidding!(3)
    assert_equal 0, round.current_bidder_seat

    # Player 0 passes
    assert round.pass_bidding!(0)
    assert_equal 1, round.current_bidder_seat

    # Player 1 passes
    assert round.pass_bidding!(1)
    assert_equal 2, round.current_bidder_seat # Dealer

    # Dealer passes - should move to calling_trump phase
    assert round.pass_bidding!(2)
    assert_equal 'calling_trump', round.trump_selection_phase
    assert_equal 3, round.current_bidder_seat # Back to left of dealer
  end

  test 'Player can call trump in calling_trump phase' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: 'JH')

    # Skip to calling_trump phase by having everyone pass
    4.times { |i| round.pass_bidding!((3 + i) % 4) }

    assert_equal 'calling_trump', round.trump_selection_phase
    assert_equal 3, round.current_bidder_seat

    # Player 3 calls spades (can't call hearts - that was turned up)
    assert round.can_call_trump?(3)
    assert_not round.call_trump!(3, 'hearts') # Can't call turned up suit
    assert round.call_trump!(3, 'spades')

    # Check results
    assert_equal 'trump_selected', round.trump_selection_phase
    assert_equal 'spades', round.trump_suit
    assert_equal 1, round.maker_team # Seat 3 is team 1
    assert_not round.ordered_up # Not ordered up, called
  end

  test 'All players passing in calling_trump throws in hand' do
    game = Game.create!
    round = game.rounds.create!(number: 1, dealer_seat: 2, turned_up_card: 'JH')

    # Skip to calling_trump phase
    4.times { |i| round.pass_bidding!((3 + i) % 4) }

    # Mock the throw_in_hand! method to track if it's called
    throw_in_called = false
    round.define_singleton_method(:throw_in_hand!) do
      throw_in_called = true
    end

    # Everyone passes in calling_trump phase
    4.times { |i| round.pass_bidding!((3 + i) % 4) }

    assert throw_in_called
  end

  # === TRICK VALIDATION TESTS ===

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

  # === CARD PLAY VALIDATION TESTS ===

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

  # === SESSION AND PLAYER TESTS ===

  test 'Session generates UUID' do
    session = Session.new(name: 'TestPlayer')
    session.save!

    assert_not_nil session.session_id
    assert session.session_id.length == 36 # UUID format
  end

  test 'Player finds teammate correctly' do
    game = Game.create!

    # Create 4 players with assigned seats and teams
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session, seat: i, team: i % 2)
    end

    # Player 0 (team 0, seat 0) should have Player 2 (team 0, seat 2) as teammate
    assert_equal players[2], players[0].teammate
    assert_equal players[0], players[2].teammate

    # Player 1 (team 1, seat 1) should have Player 3 (team 1, seat 3) as teammate
    assert_equal players[3], players[1].teammate
    assert_equal players[1], players[3].teammate
  end

  test 'Player finds opponents correctly' do
    game = Game.create!

    # Create 4 players
    players = []
    4.times do |i|
      session = Session.create!(name: "Player#{i}")
      players << game.players.create!(session: session, seat: i, team: i % 2)
    end

    # Player 0 (team 0) should have players 1 and 3 (team 1) as opponents
    opponents = players[0].opponents.to_a
    assert_includes opponents, players[1]
    assert_includes opponents, players[3]
    assert_not_includes opponents, players[2]
  end

  # === INTEGRATION TESTS ===

  test 'Full game flow from waiting to active' do
    game_setup = create_game_with_players(4)
    game = Game.find_by(code: game_setup[:game_code])

    # Game should now be active
    assert_equal 'active', game.state
    assert_equal 4, game.players.count

    # All players should have seats and teams
    game.players.each do |player|
      assert_not_nil player.seat
      assert_not_nil player.team
    end

    # Should have a current round
    assert_not_nil game.current_round
    assert_equal 1, game.current_round.number
  end

  # Helper methods for test setup would go here
end
