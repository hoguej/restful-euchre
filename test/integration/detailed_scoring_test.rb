require 'test_helper'

class DetailedScoringTest < ActionDispatch::IntegrationTest
  test 'Round stores points and reason when trump maker wins with 3-4 tricks' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0
    )

    # Create 5 tricks with team 0 winning 3
    create_tricks_for_round(round, team_0_wins: 3, team_1_wins: 2)

    round.complete_round!

    assert_equal 0, round.winning_team
    assert_equal 1, round.points_scored
    assert_equal 'made_trump', round.scoring_reason
  end

  test 'Round stores points and reason when trump maker wins with sweep (5 tricks)' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0
    )

    # Create 5 tricks with team 0 winning all 5
    create_tricks_for_round(round, team_0_wins: 5, team_1_wins: 0)

    round.complete_round!

    assert_equal 0, round.winning_team
    assert_equal 2, round.points_scored
    assert_equal 'sweep', round.scoring_reason
  end

  test 'Round stores points and reason when trump maker gets euchred' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0
    )

    # Create 5 tricks with team 1 winning more (euchre)
    create_tricks_for_round(round, team_0_wins: 2, team_1_wins: 3)

    round.complete_round!

    assert_equal 1, round.winning_team
    assert_equal 2, round.points_scored
    assert_equal 'euchre', round.scoring_reason
  end

  test 'Round stores points and reason for loner sweep' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      loner: true
    )

    # Create 5 tricks with team 0 winning all 5 (loner sweep)
    create_tricks_for_round(round, team_0_wins: 5, team_1_wins: 0)

    round.complete_round!

    assert_equal 0, round.winning_team
    assert_equal 4, round.points_scored
    assert_equal 'loner_sweep', round.scoring_reason
  end

  test 'Round stores points and reason for thrown in hand' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_selection_phase: 'ordering_up'
    )

    round.throw_in_hand!

    assert_equal 0, round.points_scored
    assert_equal 'thrown_in', round.scoring_reason
  end

  test 'Game team_score uses stored points_scored values' do
    game = Game.create!
    game.update!(state: 'active')

    # Create completed rounds with stored scoring details
    game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      winning_team: 0,
      points_scored: 1,
      scoring_reason: 'made_trump'
    )

    game.rounds.create!(
      number: 2,
      dealer_seat: 1,
      turned_up_card: generate_test_card,
      trump_suit: 'spades',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      winning_team: 1,
      points_scored: 2,
      scoring_reason: 'euchre'
    )

    game.rounds.create!(
      number: 3,
      dealer_seat: 2,
      turned_up_card: generate_test_card,
      trump_suit: 'clubs',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      winning_team: 0,
      points_scored: 2,
      scoring_reason: 'sweep'
    )

    # Team 0: 1 (made trump) + 0 (euchred) + 2 (sweep) = 3 points
    # Team 1: 0 + 2 (euchre) + 0 = 2 points
    assert_equal 3, game.team_score(0)
    assert_equal 2, game.team_score(1)
  end

  test 'Round validates points_scored is non-negative' do
    game = Game.create!
    round = game.rounds.build(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      points_scored: -1
    )

    assert_not round.valid?
    assert_includes round.errors[:points_scored], 'must be greater than or equal to 0'
  end

  test 'Round has valid scoring_reason enum values' do
    # Test that all expected enum values are valid
    valid_reasons = Round::SCORING_REASONS
    assert_includes valid_reasons, 'made_trump'
    assert_includes valid_reasons, 'sweep'
    assert_includes valid_reasons, 'euchre'
    assert_includes valid_reasons, 'loner_sweep'
    assert_includes valid_reasons, 'thrown_in'
  end

  test 'Round scoring_reason enum works correctly' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      scoring_reason: 'made_trump'
    )

    assert round.made_trump?
    assert_not round.sweep?
    assert_not round.euchre?
    assert_not round.loner_sweep?
    assert_not round.thrown_in?
  end

  test 'Backward compatibility - points_scored method works without stored values' do
    game = Game.create!
    round = game.rounds.create!(
      number: 1,
      dealer_seat: 0,
      turned_up_card: generate_test_card,
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      winning_team: 0
      # No points_scored or scoring_reason set
    )

    # Create 5 tricks with team 0 winning 3 (should calculate to 1 point)
    create_tricks_for_round(round, team_0_wins: 3, team_1_wins: 2)

    # Should fall back to calculation when no stored value
    assert_equal 1, round.points_scored
  end

  test 'Games controller includes scoring details in round JSON' do
    game_setup = create_game_with_players(4)
    game = Game.find_by(code: game_setup[:game_code])

    # Complete a round with scoring details
    round = game.current_round
    round.update!(
      trump_suit: 'hearts',
      trump_selection_phase: 'trump_selected',
      maker_team: 0,
      winning_team: 0,
      points_scored: 1,
      scoring_reason: 'made_trump'
    )

    get "/games/#{game.code}"
    assert_response :success

    response_data = JSON.parse(response.body)
    round_data = response_data['current_round']

    assert_equal 1, round_data['points_scored']
    assert_equal 'made_trump', round_data['scoring_reason']
  end

  private

  def create_tricks_for_round(round, team_0_wins:, team_1_wins:)
    # Ensure we create exactly 5 tricks
    raise ArgumentError, 'Must total 5 tricks' unless team_0_wins + team_1_wins == 5

    previous_winner = nil

    5.times do |trick_number|
      # Determine which team wins this trick
      winning_seat = if trick_number < team_0_wins
                       [0, 2].sample # Team 0 seats
                     else
                       [1, 3].sample # Team 1 seats
                     end

      # First trick is led by player to left of dealer, subsequent by previous winner
      lead_seat = if trick_number == 0
                    (round.dealer_seat + 1) % 4
                  else
                    previous_winner
                  end

      trick = round.tricks.create!(
        number: trick_number,
        lead_seat: lead_seat,
        winning_seat: winning_seat
      )

      previous_winner = winning_seat

      # Create 4 card plays for the trick
      4.times do |play_order|
        seat = (trick.lead_seat + play_order) % 4

        # Find or create player for this seat
        player = round.game.players.find_by(seat: seat)
        unless player
          session = Session.create!(name: "Player#{seat}")
          player = round.game.players.create!(
            session: session,
            seat: seat,
            team: seat % 2
          )
        end

        trick.card_plays.create!(
          player: player,
          card: "#{%w[9 T J Q K A].sample}#{%w[H D C S].sample}",
          play_order: play_order
        )
      end
    end
  end
end
