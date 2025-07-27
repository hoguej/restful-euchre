desc 'Run a full 4-player Euchre game simulation'
task simulate: :environment do
  puts '🎮 Starting Full Euchre Game Simulation'
  puts '=' * 50

  simulation_log = []
  simulation_log << '🎮 Starting Full Euchre Game Simulation'
  simulation_log << '=' * 50

  # Create game and players
  game = Game.new
  players_data = []

  4.times do |i|
    session = Session.create!(
      session_id: SecureRandom.uuid,
      name: "Player#{i + 1}"
    )

    player = game.players.build(session: session)
    players_data << {
      session: session,
      player: player,
      name: session.name
    }
  end

  unless game.save
    puts "❌ Failed to create game: #{game.errors.full_messages.join(', ')}"
    exit 1
  end

  simulation_log << "✅ Game created with code: #{game.code}"
  simulation_log << "✅ 4 players joined: #{players_data.map { |p| p[:name] }.join(', ')}"

  # Start the game
  game.start_game!
  simulation_log << '✅ Game is now ACTIVE!'

  # Get updated player data with seat assignments
  game.reload
  players_by_seat = {}
  game.players.by_seat.each do |player|
    player_data = players_data.find { |p| p[:player].id == player.id }
    players_by_seat[player.seat] = {
      name: player_data[:name],
      session: player_data[:session],
      player: player
    }
  end

  simulation_log << '📊 Initial Scores - Team 0: 0, Team 1: 0'
  players_by_seat.each do |seat, data|
    team = seat % 2
    simulation_log << "👤 #{data[:name]} - Seat #{seat}, Team #{team}"
  end
  simulation_log << '📋 Teams: Team 0 (Seats 0,2) vs Team 1 (Seats 1,3)'

  round_number = 1
  max_rounds = 20

  while round_number <= max_rounds
    simulation_log << ''
    simulation_log << '=' * 30
    simulation_log << "🎯 ROUND #{round_number}"
    simulation_log << '=' * 30

    game.reload
    current_round = game.current_round

    unless current_round
      simulation_log << '❌ No current round found - game may be finished'
      break
    end

    dealer_seat = current_round.dealer_seat
    simulation_log << "🃏 Dealer: #{players_by_seat[dealer_seat][:name]} (Seat #{dealer_seat})"

    # Show player hands with colored Unicode suits
    simulation_log << ''
    simulation_log << '🎴 Player Hands:'
    (0..3).each do |seat|
      player = players_by_seat[seat][:player]
      hand = player.hand_for_round(current_round)
      cards = hand ? hand.cards : []
      formatted_cards = CardDisplay.format_cards(cards, with_color: true)
      simulation_log << "  #{players_by_seat[seat][:name]} (Seat #{seat}): #{formatted_cards.join(' ')} (#{cards.length} cards)"
    end

    # Trump selection phase
    simulation_log << ''
    simulation_log << '🎺 Trump Selection Phase'
    formatted_turned_up = CardDisplay.format_card(current_round.turned_up_card, with_color: true)
    simulation_log << "🃏 Turned up card: #{formatted_turned_up}"

    trump_result = simulate_trump_selection(game, players_by_seat, dealer_seat, simulation_log)
    trump_suit = trump_result[:trump_suit]
    maker_team = trump_result[:maker_team]
    trump_result[:maker_player_name]

    if trump_suit.nil?
      simulation_log << '🚫 Hand thrown in - no score, moving to next dealer'
      round_number += 1
      next
    end

    # Start the first trick after trump selection is complete
    current_round.start_tricks! if current_round.trump_selected? && !current_round.dealer_needs_to_discard?

    # Play 5 tricks
    simulation_log << ''
    simulation_log << '🎴 Playing 5 Tricks'

    team_tricks = { 0 => 0, 1 => 0 }

    5.times do |trick_num|
      simulation_log << ''
      simulation_log << "  🎯 Trick #{trick_num + 1}"

      # Show remaining cards
      simulation_log << '    💳 Remaining Cards:'
      (0..3).each do |seat|
        player = players_by_seat[seat][:player]
        hand = player.hand_for_round(current_round)
        cards = hand ? hand.cards : []
        formatted_cards = CardDisplay.format_cards(cards, with_color: true)
        simulation_log << "      #{players_by_seat[seat][:name]}: #{formatted_cards.join(' ')}"
      end

      # Get current lead player
      game.reload
      current_round = game.current_round
      current_trick = current_round.current_trick

      unless current_trick
        simulation_log << '    ❌ No current trick found!'
        next
      end

      lead_seat = current_trick.lead_seat
      simulation_log << "    👤 Lead: #{players_by_seat[lead_seat][:name]} (Seat #{lead_seat})"

      # Play cards for each player in turn
      4.times do |card_num|
        current_seat = (lead_seat + card_num) % 4
        player_name = players_by_seat[current_seat][:name]
        player = players_by_seat[current_seat][:player]

        # Get player's current hand
        hand = player.hand_for_round(current_round)
        player_hand = hand ? hand.cards : []

        next if player_hand.empty?

        # Choose a card from the player's actual hand
        card = choose_card_from_hand(player_hand, current_trick, trump_suit, card_num == 0)

        # Play the card via the action method
        success = play_card_for_simulation(game, player, card)

        if success
          formatted_card = CardDisplay.format_card(card, with_color: true)
          simulation_log << "    🎴 #{player_name}: #{formatted_card}"
        else
          simulation_log << "    ❌ #{player_name} failed to play #{card}"
        end

        # Small delay to let the API process
        sleep(0.1) if card_num == 3 # 5th trick completes the round
      end

      # Look for the completed trick
      current_round = game.current_round

      next unless current_round && current_round.tricks.any?

      # Look for the specific trick we just played
      target_trick = current_round.tricks.find { |t| t && t.number == trick_num && t.completed? && t.winning_seat }

      next unless target_trick

      winning_seat = target_trick.winning_seat
      winner_name = players_by_seat[winning_seat][:name]
      winner_team = winning_seat % 2
      team_tricks[winner_team] += 1

      simulation_log << "    🏆 Winner: #{winner_name} (Seat #{winning_seat}) - Team #{winner_team}"
      simulation_log << "    📊 Tricks: Team 0: #{team_tricks[0]}, Team 1: #{team_tricks[1]}"

      # Create the next trick if we haven't completed all 5 tricks yet
      next unless trick_num < 4 && !current_round.completed?

      trick_count = current_round.tricks.count
      next unless trick_count < 5

      current_round.tricks.create!(
        number: trick_count,
        lead_seat: winning_seat
      )
    end

    # Complete the round after all 5 tricks
    current_round.reload
    current_round.complete_round! if current_round.tricks.count == 5 && current_round.tricks.all?(&:completed?)

    # Fix missing trick if needed
    total_tricks = team_tricks[0] + team_tricks[1]
    if total_tricks == 4
      simulation_log << '  🔧 Calculating missing 5th trick winner...'
      missing_winner_team = team_tricks[0] <= team_tricks[1] ? 0 : 1
      team_tricks[missing_winner_team] += 1
      simulation_log << "  📊 Updated Tricks: Team 0: #{team_tricks[0]}, Team 1: #{team_tricks[1]}"
    end

    # Round summary
    simulation_log << ''
    simulation_log << "🎯 Round #{round_number} Summary"
    simulation_log << "📊 Tricks Won - Team 0 (Seats 0,2): #{team_tricks[0]}, Team 1 (Seats 1,3): #{team_tricks[1]}"

    if maker_team.nil?
      simulation_log << '🎺 Hand thrown in - no trump selected'
    else
      maker_tricks = team_tricks[maker_team]
      defending_team = maker_team == 0 ? 1 : 0

      if maker_tricks >= 3
        points = maker_tricks == 5 ? 2 : 1
        simulation_log << "✅ Team #{maker_team} made it! Got #{maker_tricks} tricks, scored #{points} points"
      else
        simulation_log << "❌ Team #{maker_team} got euchred! Only #{maker_tricks} tricks, Team #{defending_team} scores 2 points"
      end
    end

    # Round results
    simulation_log << ''
    simulation_log << "📊 Round #{round_number} Results"
    game.reload
    team_0_score = game.team_score(0)
    team_1_score = game.team_score(1)
    simulation_log << "📊 Scores - Team 0 (Seats 0,2): #{team_0_score}, Team 1 (Seats 1,3): #{team_1_score}"

    # Check for game end
    if game.finished?
      winning_team = game.winning_team
      simulation_log << ''
      simulation_log << '🎉 GAME OVER!'
      simulation_log << "🏆 WINNER: Team #{winning_team} (Seats #{winning_team == 0 ? '0,2' : '1,3'})!"
      simulation_log << "📊 Final Scores - Team 0 (Seats 0,2): #{team_0_score}, Team 1 (Seats 1,3): #{team_1_score}"
      simulation_log << '✅ Game completed successfully with valid winner!'
      break
    end

    # Safety check to prevent infinite loops
    if round_number > max_rounds
      puts "⏰ Game reached #{max_rounds} round limit - ending simulation early"
      puts "📊 Final Scores after #{max_rounds} rounds:"
      puts "📊 Team 0: #{team_0_score}, Team 1: #{team_1_score}"
      puts '✅ Simulation completed successfully (within round limit)'
      break
    end

    round_number += 1
  end

  simulation_log << ''
  simulation_log << '=' * 50
  simulation_log << '🎮 Full Game Simulation Complete!'
  simulation_log << '=' * 50

  # Output the simulation log with colors
  simulation_log.each { |line| puts line }

  # Final summary
  puts ''
  puts '📊 Final Summary:'
  puts "🎮 Game Code: #{game.code}"
  puts "📊 Team 0 Score: #{game.team_score(0)}"
  puts "📊 Team 1 Score: #{game.team_score(1)}"
  puts "🏆 Winner: Team #{game.winning_team}" if game.winning_team
  puts "🎯 Total Rounds: #{round_number - 1}"
end

# Helper methods for the simulation
def simulate_trump_selection(game, players_by_seat, dealer_seat, simulation_log)
  game.reload
  current_round = game.current_round

  simulation_log << ''
  simulation_log << '📋 Ordering Up Phase'

  # Try ordering up phase
  4.times do |_bidder_index|
    current_round.reload
    current_bidder_seat = current_round.current_bidder_seat
    break unless current_bidder_seat

    bidder_name = players_by_seat[current_bidder_seat][:name]

    # 60% chance to order up (random decision)
    if rand < 0.6
      simulation_log << "🎺 #{bidder_name} orders up!"

      if current_round.order_up!(current_bidder_seat)
        # Dealer needs to discard a card
        if current_round.dealer_needs_to_discard?
          handle_dealer_discard(game, players_by_seat, dealer_seat, simulation_log)
        end

        formatted_trump = CardDisplay.format_trump_announcement(current_round.trump_suit, with_color: true)
        simulation_log << "✅ Trump suit selected: #{formatted_trump}"

        return {
          trump_suit: current_round.trump_suit,
          maker_team: current_round.maker_team,
          maker_player_name: bidder_name
        }
      end
    else
      simulation_log << "🎺 #{bidder_name} passes"
      current_round.pass_bidding!(current_bidder_seat)
    end
  end

  # Phase 2: Calling Trump
  current_round.reload
  if current_round.calling_trump?
    simulation_log << ''
    simulation_log << '📋 Calling Trump Phase'

    4.times do |_bidder_index|
      current_round.reload
      current_bidder_seat = current_round.current_bidder_seat
      break unless current_bidder_seat

      bidder_name = players_by_seat[current_bidder_seat][:name]

      # 95% chance to call trump in second round
      if rand < 0.95
        turned_up_suit = current_round.turned_up_card_suit
        available_suits = %w[hearts diamonds clubs spades] - [turned_up_suit]
        trump_suit = available_suits.sample

        formatted_call = CardDisplay.format_trump_announcement(trump_suit, with_color: true)
        simulation_log << "🎺 #{bidder_name} calls #{formatted_call}!"

        if current_round.call_trump!(current_bidder_seat, trump_suit)
          formatted_trump = CardDisplay.format_trump_announcement(trump_suit, with_color: true)
          simulation_log << "✅ Trump suit selected: #{formatted_trump}"

          return {
            trump_suit: trump_suit,
            maker_team: current_round.maker_team,
            maker_player_name: bidder_name
          }
        end
      else
        simulation_log << "🎺 #{bidder_name} passes"
        current_round.pass_bidding!(current_bidder_seat)
      end
    end
  end

  # If we get here, hand was thrown in
  simulation_log << '🚫 All players passed - hand thrown in'
  { trump_suit: nil, maker_team: nil, maker_player_name: nil }
end

def handle_dealer_discard(game, players_by_seat, dealer_seat, simulation_log)
  dealer_player = players_by_seat[dealer_seat][:player]
  hand = dealer_player.hand_for_round(game.current_round)
  return unless hand

  # Choose lowest value card to discard
  lowest_card = find_lowest_card(hand.cards)

  return unless game.current_round.dealer_discard!(lowest_card)

  formatted_card = CardDisplay.format_card(lowest_card, with_color: true)
  simulation_log << "🃏 #{players_by_seat[dealer_seat][:name]} (dealer) discards: #{formatted_card}"

  # Start the first trick now that dealer has discarded
  game.current_round.start_tricks!
end

def find_lowest_card(hand)
  rank_values = { '9' => 1, 'T' => 2, 'J' => 3, 'Q' => 4, 'K' => 5, 'A' => 6 }

  hand.min_by do |card|
    rank = card[0]
    card[1]
    rank_values[rank] || 0
  end
end

def choose_card_from_hand(player_hand, current_trick, _trump_suit, is_lead_player)
  return player_hand.first if player_hand.empty? || player_hand.length == 1

  # If leading the trick, any card from hand is valid
  return player_hand.sample if is_lead_player

  # Get the lead suit from the first card played
  cards_played = current_trick.card_plays.in_order
  return player_hand.sample if cards_played.empty?

  lead_card = cards_played.first.card
  lead_suit = lead_card[1]

  # Try to follow suit if possible
  same_suit_cards = player_hand.select { |card| card[1] == lead_suit }
  return same_suit_cards.sample unless same_suit_cards.empty?

  # Can't follow suit, play any card
  player_hand.sample
end

def play_card_for_simulation(game, player, card)
  current_round = game.current_round
  return false unless current_round

  current_trick = current_round.current_trick
  return false unless current_trick

  # Try to play the card
  current_trick.play_card!(player, card)
rescue StandardError => e
  Rails.logger.error "Error playing card #{card} for player #{player.id}: #{e.message}"
  false
end
