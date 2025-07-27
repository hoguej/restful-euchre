require 'test_helper'

class TrumpSelectionTest < ActionDispatch::IntegrationTest
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
end
