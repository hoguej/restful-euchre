require 'test_helper'

class PlayerSessionTest < ActionDispatch::IntegrationTest
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
end
