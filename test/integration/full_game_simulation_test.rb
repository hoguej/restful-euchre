require 'test_helper'

class FullGameSimulationTest < ActionDispatch::IntegrationTest
  test 'Complete 4-player Euchre game from start to finish' do
    puts "\n🎮 Starting Full Euchre Game Simulation"
    puts '=' * 50

    # === GAME SETUP ===
    game_setup = create_game_with_players(4)
    game_code = game_setup[:game_code]
    players = game_setup[:players]

    puts "✅ Game created with code: #{game_code}"
    puts "✅ 4 players joined: #{players.map { |p| p[:data]['name'] }.join(', ')}"

    # Verify game is active
    game_state = get_game_state(game_code)
    assert_equal 'active', game_state['game']['state']
    assert_equal 4, game_state['game']['player_count']

    puts '✅ Game is now ACTIVE!'
    puts "📊 Initial Scores - Team 0: #{game_state['scores']['team_0']}, Team 1: #{game_state['scores']['team_1']}"

    # Map players by seat for easier reference
    players_by_seat = {}
    game_state['players'].each do |player|
      seat = player['seat']
      name = player['name']
      team = player['team']
      players_by_seat[seat] = { name: name, team: team, session_name: name }
      puts "👤 #{name} - Seat #{seat}, Team #{team}"
    end

    round_number = 1
    max_rounds = 30

    # === MAIN GAME LOOP ===
    while true
      # Safety check to prevent infinite loops
      if round_number > max_rounds
        flunk "🚨 Game exceeded #{max_rounds} rounds - likely infinite loop in trump selection!"
      end

      puts "\n" + '=' * 30
      puts "🎯 ROUND #{round_number}"
      puts '=' * 30

      game_state = get_game_state(game_code)
      current_round = game_state['current_round']

      if current_round.nil?
        puts '❌ No current round found - game may be finished'
        break
      end

      dealer_seat = current_round['dealer_seat']
      puts "🃏 Dealer: #{players_by_seat[dealer_seat][:name]} (Seat #{dealer_seat})"

      # === TRUMP SELECTION PHASE ===
      trump_suit = simulate_trump_selection(game_code, players_by_seat, dealer_seat)

      if trump_suit.nil?
        puts '🚫 Hand thrown in - no score, moving to next dealer'
        round_number += 1
        next
      end

      # Get updated game state after trump selection
      game_state = get_game_state(game_code)
      current_round = game_state['current_round']

      maker_team = current_round['maker_team']
      puts "👥 Making team: Team #{maker_team}"

      # === PLAY 5 TRICKS ===
      puts "\n🎴 Playing 5 Tricks"

      5.times do |trick_num|
        puts "\n  🎯 Trick #{trick_num + 1}"

        # Get current game state to find the current trick
        game_state = get_game_state(game_code)
        current_round = game_state['current_round']
        current_trick = current_round['current_trick']

        if current_trick.nil?
          puts '    ❌ No current trick found'
          break
        end

        lead_seat = current_trick['lead_seat']
        puts "    👤 Lead: #{players_by_seat[lead_seat][:name]} (Seat #{lead_seat})"

        # Play 4 cards in order
        4.times do |card_num|
          game_state = get_game_state(game_code)
          current_trick = game_state['current_round']['current_trick']
          current_turn_seat = current_trick['current_turn_seat']

          if current_turn_seat.nil?
            puts "    ✅ Trick #{trick_num + 1} completed"
            break
          end

          player_name = players_by_seat[current_turn_seat][:name]

          # Switch to current player's session
          switch_to_session(player_name)

          # Generate a realistic card for this position
          card = generate_realistic_card(trump_suit, current_trick, card_num)

          # Play the card
          make_action(game_code, 'play_card', { card: card })

          if response.status == 200
            puts "    🎴 #{player_name}: #{card}"
          else
            puts "    ❌ #{player_name} failed to play #{card}: #{JSON.parse(response.body)['error']}"
          end
        end

        # Get trick results
        game_state = get_game_state(game_code)
        current_round = game_state['current_round']

        next unless current_round['current_trick'] && current_round['current_trick']['completed']

        winning_seat = current_round['current_trick']['winning_seat']
        winner_name = players_by_seat[winning_seat][:name]
        puts "    🏆 Winner: #{winner_name} (Seat #{winning_seat})"
      end

      # === ROUND COMPLETION ===
      puts "\n📊 Round #{round_number} Results"

      # Get final game state
      game_state = get_game_state(game_code)

      team_0_score = game_state['scores']['team_0']
      team_1_score = game_state['scores']['team_1']

      puts "📊 Scores - Team 0: #{team_0_score}, Team 1: #{team_1_score}"

      # Check for game end
      if game_state['game']['state'] == 'finished'
        winning_team = game_state['game']['winning_team']
        puts "\n🎉 GAME OVER!"
        puts "🏆 WINNER: Team #{winning_team}!"
        puts "📊 Final Scores - Team 0: #{team_0_score}, Team 1: #{team_1_score}"

        # Verify winner
        assert_not_nil winning_team
        assert_includes [0, 1], winning_team
        assert [team_0_score, team_1_score].max >= 10

        puts '✅ Game completed successfully with valid winner!'
        puts "🎯 Total rounds played: #{round_number}"
        break
      end

      round_number += 1
    end

    puts "\n" + '=' * 50
    puts '🎮 Full Game Simulation Complete!'
    puts '=' * 50
  end

  private

  def simulate_trump_selection(game_code, players_by_seat, dealer_seat)
    puts "\n🎺 Trump Selection Phase"
    game_state = get_game_state(game_code)
    current_round = game_state['current_round']
    turned_up_card = current_round['turned_up_card']
    puts "🃏 Turned up card: #{turned_up_card}"

    # Phase 1: Ordering Up
    puts "\n📋 Ordering Up Phase"

    # Keep bidding until someone orders up or all players pass
    while true
      game_state = get_game_state(game_code)
      current_round = game_state['current_round']

      # Break if we're no longer in ordering up phase
      break unless current_round['trump_selection_phase'] == 'ordering_up'

      current_player_seat = current_round['current_bidder_seat']
      player_name = players_by_seat[current_player_seat][:name]
      switch_to_session(player_name)

      # 80% chance to order up
      if rand < 0.8
        puts "🎺 #{player_name} orders up!"
        make_action(game_code, 'order_up')

        if response.status == 200
          response_data = JSON.parse(response.body)
          trump_suit = response_data['round']['trump_suit']

          # Handle dealer discard if needed
          if response_data['message'].include?('dealer must discard')
            handle_dealer_discard(game_code, players_by_seat, dealer_seat)
          end

          puts "✅ Trump suit selected: #{trump_suit.upcase}"
          puts "👥 Making team: Team #{response_data['round']['maker_team']}"
          return trump_suit
        else
          puts "   ❌ Failed to order up: #{JSON.parse(response.body)['error']}"
        end
      else
        puts "👋 #{player_name} passes"
        make_action(game_code, 'pass')
      end
    end

    # Phase 2: Calling Trump (if all passed ordering up)
    puts "\n📋 Calling Trump Phase"
    turned_up_suit = get_suit_from_card(turned_up_card)
    available_suits = %w[hearts diamonds clubs spades] - [turned_up_suit]

    # Keep bidding until someone calls trump or all players pass
    while true
      game_state = get_game_state(game_code)
      current_round = game_state['current_round']

      # Break if we're no longer in calling trump phase
      break unless current_round['trump_selection_phase'] == 'calling_trump'

      current_player_seat = current_round['current_bidder_seat']
      player_name = players_by_seat[current_player_seat][:name]
      switch_to_session(player_name)

      # 95% chance to call trump in second round
      if rand < 0.95
        trump_suit = available_suits.sample
        puts "🎺 #{player_name} calls #{trump_suit.upcase}!"

        make_action(game_code, 'call_trump', { trump_suit: trump_suit })

        if response.status == 200
          response_data = JSON.parse(response.body)
          puts "✅ Trump suit selected: #{trump_suit.upcase}"
          puts "👥 Making team: Team #{response_data['round']['maker_team']}"
          return trump_suit
        else
          puts "   ❌ Failed to call trump: #{JSON.parse(response.body)['error']}"
        end
      else
        puts "👋 #{player_name} passes"
        make_action(game_code, 'pass')
      end
    end

    # If everyone passed both phases, the hand is thrown in
    puts '🚫 All players passed - hand thrown in'
    nil
  end

  def handle_dealer_discard(game_code, players_by_seat, dealer_seat)
    dealer_name = players_by_seat[dealer_seat][:name]
    switch_to_session(dealer_name)

    # Generate a realistic discard (lowest card)
    discard_card = '9H' # For simplicity, always discard 9 of hearts
    puts "🃏 #{dealer_name} (dealer) discards: #{discard_card}"

    make_action(game_code, 'discard_card', { card: discard_card })
  end

  def get_suit_from_card(card)
    return nil unless card && card.length == 2

    case card[1]
    when 'H' then 'hearts'
    when 'D' then 'diamonds'
    when 'C' then 'clubs'
    when 'S' then 'spades'
    end
  end

  def generate_realistic_card(_trump_suit, current_trick, _card_position)
    # All possible cards in Euchre deck
    ranks = %w[9 T J Q K A] # T = 10
    suits = %w[H D C S]

    all_cards = []
    ranks.each do |rank|
      suits.each do |suit|
        all_cards << "#{rank}#{suit}"
      end
    end

    # Get cards already played in this trick
    played_cards = current_trick['cards_played']&.map { |play| play['card'] } || []

    # Remove played cards from available cards
    available_cards = all_cards - played_cards

    # For simplicity, just return a random available card
    # In a real simulation, this would consider strategy, following suit, etc.
    available_cards.sample || '9H' # Fallback
  end
end
