require 'test_helper'

class RoundLogicTest < ActionDispatch::IntegrationTest
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
end
