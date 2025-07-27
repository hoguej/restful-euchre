require 'test_helper'

class GameStateTest < ActionDispatch::IntegrationTest
  test 'Game generates unique codes' do
    game1 = Game.create!
    game2 = Game.create!

    assert_not_equal game1.code, game2.code
    assert game1.code.length > 0
    assert game2.code.length > 0
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
end
