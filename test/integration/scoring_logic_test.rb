require 'test_helper'

class ScoringLogicTest < ActionDispatch::IntegrationTest
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
end
