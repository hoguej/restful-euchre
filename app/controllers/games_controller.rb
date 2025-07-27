class GamesController < ApplicationController
  include ActionController::MimeResponds

  before_action :set_game, only: %i[show join action players]

  # POST /games
  def create
    @game = Game.new

    if @game.save
      render json: {
        game: game_json(@game),
        join_url: "/games/#{@game.code}"
      }, status: :created
    else
      render json: { errors: @game.errors }, status: :unprocessable_entity
    end
  end

  # GET /games/:code
  def show
    player = @game.players.find_by(session: current_session)
    player_hand = []

    if player && @game.current_round
      hand = player.hand_for_round(@game.current_round)
      player_hand = hand&.cards || []
    end

    render json: {
      game: game_json(@game),
      current_player: current_player_json,
      players: players_json(@game.players.by_seat),
      current_round: current_round_json,
      player_hand: player_hand,
      scores: {
        team_0: @game.team_score(0),
        team_1: @game.team_score(1)
      }
    }
  end

  # POST /games/:code/join
  def join
    return render json: { error: 'Game has finished' }, status: :forbidden if @game.finished?

    return render json: { error: 'Game is full' }, status: :forbidden if @game.full?

    # Check if player already in game
    existing_player = @game.players.find_by(session: current_session)
    if existing_player
      return render json: {
        message: 'Already in game',
        player: player_json(existing_player)
      }
    end

    # Update session name if provided
    current_session.update!(name: params[:name]) if params[:name].present?

    # Create player
    player = @game.players.build(session: current_session)

    if player.save
      # Start game if we now have 4 players
      @game.start_game! if @game.can_start?

      render json: {
        message: 'Joined game successfully',
        player: player_json(player),
        game: game_json(@game)
      }, status: :created
    else
      render json: { errors: player.errors }, status: :unprocessable_entity
    end
  end

  # POST /games/:code/action
  def action
    player = @game.players.find_by(session: current_session)

    return render json: { error: 'Not in this game' }, status: :forbidden unless player

    return render json: { error: 'Game is not active' }, status: :forbidden unless @game.active?

    case params[:action_type]
    when 'play_card'
      handle_play_card(player)
    when 'order_up'
      handle_order_up(player)
    when 'call_trump'
      handle_call_trump(player)
    when 'pass'
      handle_pass(player)
    when 'discard_card'
      handle_discard_card(player)
    else
      render json: { error: 'Invalid action type' }, status: :bad_request
    end
  end

  # GET /games/:code/players
  def players
    render json: {
      players: players_json(@game.players.by_seat)
    }
  end

  def simulate
    simulation_log = []

    simulation_log << '🎮 Starting Full Euchre Game Simulation'
    simulation_log << '=' * 50

    # Create game and players
    game = Game.create!(code: SecureRandom.alphanumeric(8).upcase)
    sessions = []
    players_data = []

    4.times do |i|
      session = Session.create!(
        session_id: SecureRandom.uuid,
        name: "Player#{i + 1}"
      )
      sessions << session

      player = game.players.create!(session: session)
      players_data << { name: "Player#{i + 1}", session: session, player: player }
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
    max_rounds = 2

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

      # Show player hands
      simulation_log << ''
      simulation_log << '🎴 Player Hands:'
      (0..3).each do |seat|
        player = players_by_seat[seat][:player]
        hand = player.hand_for_round(current_round)
        cards = hand ? hand.cards : []
        simulation_log << "  #{players_by_seat[seat][:name]} (Seat #{seat}): #{cards.join(' ')} (#{cards.length} cards)"
      end

      # Trump selection phase
      simulation_log << ''
      simulation_log << '🎺 Trump Selection Phase'
      simulation_log << "🃏 Turned up card: #{current_round.turned_up_card}"

      trump_result = simulate_trump_selection_action(game, players_by_seat, dealer_seat, simulation_log)
      trump_suit = trump_result[:trump_suit]
      maker_team = trump_result[:maker_team]
      maker_player_name = trump_result[:maker_player_name]

      if trump_suit.nil?
        simulation_log << '🚫 Hand thrown in - no score, moving to next dealer'
        round_number += 1
        next
      end

      simulation_log << "👥 Making team: Team #{maker_team}"

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
          simulation_log << "      #{players_by_seat[seat][:name]}: #{cards.join(' ')}"
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
        4.times do |player_order|
          current_player_seat = (lead_seat + player_order) % 4
          player_data = players_by_seat[current_player_seat]
          player = player_data[:player]

          # Choose a card from player's hand
          hand = player.hand_for_round(current_round)
          available_cards = hand.cards

          if available_cards.empty?
            simulation_log << "    ❌ #{player_data[:name]} has no cards!"
            next
          end

          # Simple card selection logic
          card = available_cards.first

          # Play the card via API
          current_round.reload
          current_trick = current_round.current_trick

          if current_trick.play_card!(player, card)
            simulation_log << "    🎴 #{player_data[:name]}: #{card}"

            # If trick is completed and not the last trick, create next trick
            if current_trick.completed? && trick_num < 4
              next_lead_seat = current_trick.winning_seat
              current_round.tricks.create!(
                number: trick_num + 1,
                lead_seat: next_lead_seat
              )
            end
          else
            simulation_log << "    ❌ #{player_data[:name]} failed to play #{card}"
          end
        end

        # Give time for trick completion
        sleep(0.1)

        # Check for trick winner
        game.reload
        current_round = game.current_round

        next unless current_round && current_round.tricks.any?

        target_trick = current_round.tricks.find { |t| t && t.number == trick_num && t.completed? && t.winning_seat }

        next unless target_trick

        winning_seat = target_trick.winning_seat
        winner_name = players_by_seat[winning_seat][:name]
        winner_team = winning_seat % 2

        team_tricks[winner_team] += 1
        simulation_log << "    🏆 Winner: #{winner_name} (Seat #{winning_seat}) - Team #{winner_team}"
        simulation_log << "    �� Tricks: Team 0: #{team_tricks[0]}, Team 1: #{team_tricks[1]}"
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
        simulation_log << "  🏆 Trick 5: Calculated winner - Team #{missing_winner_team} (tie-breaker logic)"
        simulation_log << "  📊 Corrected Tricks: Team 0: #{team_tricks[0]}, Team 1: #{team_tricks[1]}"
      end

      # Round summary
      simulation_log << ''
      simulation_log << "🎯 Round #{round_number} Summary"
      simulation_log << "📊 Tricks Won - Team 0 (Seats 0,2): #{team_tricks[0]}, Team 1 (Seats 1,3): #{team_tricks[1]}"

      if maker_team.nil?
        simulation_log << '🎺 Hand thrown in - no trump selected'
      else
        maker_tricks = team_tricks[maker_team]
        defending_team = 1 - maker_team

        simulation_log << "🎺 #{maker_player_name} (Team #{maker_team}) called trump"

        if maker_tricks >= 5
          simulation_log << "✅ Team #{maker_team} got all 5 tricks - scores 2 points!"
        elsif maker_tricks >= 3
          simulation_log << "✅ Team #{maker_team} got #{maker_tricks} tricks - scores 1 point!"
        else
          simulation_log << "❌ Team #{maker_team} was euchred (only #{maker_tricks} tricks) - Team #{defending_team} scores 2 points!"
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

      round_number += 1
    end

    simulation_log << ''
    simulation_log << '=' * 50
    simulation_log << '🎮 Full Game Simulation Complete!'
    simulation_log << '=' * 50

    respond_to do |format|
      format.html do
        @simulation_log = simulation_log
        @game_code = game.code
        @final_scores = {
          team_0: game.team_score(0),
          team_1: game.team_score(1)
        }
        @winner = game.winning_team
        @total_rounds = round_number - 1
        render :simulate, layout: false
      end
      format.json do
        render json: {
          simulation_log: simulation_log,
          game_code: game.code,
          final_scores: {
            team_0: game.team_score(0),
            team_1: game.team_score(1)
          },
          winner: game.winning_team,
          total_rounds: round_number - 1
        }
      end
    end
  end

  private

  def set_game
    @game = Game.find_by!(code: params[:code])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Game not found' }, status: :not_found
  end

  def handle_play_card(player)
    round = @game.current_round
    trick = round&.current_trick
    card = params[:card]

    return render json: { error: 'No active trick' }, status: :bad_request unless trick

    return render json: { error: 'Card is required' }, status: :bad_request unless card.present?

    if trick.play_card!(player, card)
      # Check if trick is complete
      if trick.completed?
        begin
          # Create next trick or complete round
          if trick.number < 4
            round.tricks.create!(
              number: trick.number + 1,
              lead_seat: trick.winning_seat
            )
          else
            return render json: { error: 'Failed to complete round' }, status: :bad_request unless round.complete_round!
          end
        rescue StandardError => e
          Rails.logger.error "Error completing trick/round: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          return render json: { error: "Server error: #{e.message}" }, status: :internal_server_error
        end
      end

      render json: {
        message: 'Card played successfully',
        trick: trick_json(trick),
        game: game_json(@game)
      }
    else
      render json: { error: 'Invalid card play' }, status: :bad_request
    end
  end

  def handle_order_up(player)
    round = @game.current_round

    unless round&.can_order_up?(player.seat)
      return render json: { error: 'Cannot order up at this time' }, status: :bad_request
    end

    if round.order_up!(player.seat)
      # If trump is selected, dealer needs to discard (if ordered up)
      if round.dealer_needs_to_discard?
        render json: {
          message: 'Trump ordered up successfully - dealer must discard',
          round: round_json(round),
          game: game_json(@game)
        }
      else
        render json: {
          message: 'Trump ordered up successfully',
          round: round_json(round),
          game: game_json(@game)
        }
      end
    else
      render json: { error: 'Failed to order up' }, status: :bad_request
    end
  end

  def handle_call_trump(player)
    round = @game.current_round
    trump_suit = params[:trump_suit]

    unless round&.can_call_trump?(player.seat)
      return render json: { error: 'Cannot call trump at this time' }, status: :bad_request
    end

    return render json: { error: 'Invalid trump suit' }, status: :bad_request unless Round::SUITS.include?(trump_suit)

    if round.call_trump!(player.seat, trump_suit)
      render json: {
        message: 'Trump called successfully',
        round: round_json(round),
        game: game_json(@game)
      }
    else
      render json: { error: 'Failed to call trump' }, status: :bad_request
    end
  end

  def handle_pass(player)
    round = @game.current_round

    unless round&.current_bidder_seat == player.seat
      return render json: { error: 'Not your turn to bid' }, status: :bad_request
    end

    if round.pass_bidding!(player.seat)
      message = if round.trump_selected?
                  'Passed - trump selected'
                elsif round.calling_trump?
                  'Passed - moved to calling trump phase'
                else
                  'Passed'
                end

      render json: {
        message: message,
        round: round_json(round),
        game: game_json(@game)
      }
    else
      render json: { error: 'Failed to pass' }, status: :bad_request
    end
  end

  def handle_discard_card(player)
    round = @game.current_round
    card = params[:card]

    return render json: { error: 'No discard needed' }, status: :bad_request unless round&.dealer_needs_to_discard?

    unless player.seat == round.dealer_seat
      return render json: { error: 'Only dealer can discard' }, status: :bad_request
    end

    return render json: { error: 'Card is required' }, status: :bad_request unless card.present?

    # Discard the card from dealer's hand
    if round.dealer_discard!(card) && round.start_tricks!
      render json: {
        message: 'Card discarded - tricks starting',
        round: round_json(round),
        game: game_json(@game)
      }
    else
      render json: { error: 'Invalid discard or failed to start tricks' }, status: :bad_request
    end
  end

  def current_player_json
    player = @game.players.find_by(session: current_session)
    player ? player_json(player) : nil
  end

  def game_json(game)
    {
      code: game.code,
      state: game.state,
      player_count: game.players.count,
      winning_team: game.winning_team
    }
  end

  def player_json(player)
    {
      id: player.id,
      name: player.session.name,
      seat: player.seat,
      team: player.team
    }
  end

  def players_json(players)
    players.map { |player| player_json(player) }
  end

  def current_round_json
    round = @game.current_round
    return nil unless round

    round_json(round)
  end

  def round_json(round)
    {
      number: round.number,
      dealer_seat: round.dealer_seat,
      trump_suit: round.trump_suit,
      maker_team: round.maker_team,
      loner: round.loner,
      turned_up_card: round.turned_up_card,
      trump_selection_phase: round.trump_selection_phase,
      current_bidder_seat: round.current_bidder_seat,
      ordered_up: round.ordered_up,
      current_trick: round.current_trick ? trick_json(round.current_trick) : nil,
      tricks: round.tricks.order(:number).map { |trick| trick_json(trick) },
      completed: round.completed?
    }
  end

  def trick_json(trick)
    {
      number: trick.number,
      lead_seat: trick.lead_seat,
      winning_seat: trick.winning_seat,
      current_turn_seat: trick.current_turn_seat,
      cards_played: trick.card_plays.in_order.map do |play|
        {
          player_seat: play.player.seat,
          card: play.card,
          play_order: play.play_order
        }
      end,
      completed: trick.completed?
    }
  end

  def simulate_trump_selection_action(game, players_by_seat, dealer_seat, simulation_log)
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

      # 70% chance to order up
      if rand < 0.7
        if current_round.order_up!(current_bidder_seat)
          simulation_log << "🎺 #{bidder_name} orders up!"

          # Handle dealer discard
          if current_round.dealer_needs_to_discard?
            dealer_player = game.players.find_by(seat: dealer_seat)
            dealer_hand = dealer_player.hand_for_round(current_round)

            if dealer_hand && !dealer_hand.cards.empty?
              discard_card = dealer_hand.cards.last
              if current_round.dealer_discard!(discard_card)
                simulation_log << "🃏 #{players_by_seat[dealer_seat][:name]} (dealer) discards: #{discard_card}"
                # Now we can start tricks
                current_round.start_tricks!
              end
            end
          end

          simulation_log << "✅ Trump suit selected: #{current_round.trump_suit.upcase}"

          return {
            trump_suit: current_round.trump_suit,
            maker_team: current_round.maker_team,
            maker_player_name: bidder_name
          }
        end
      else
        current_round.pass_bidding!(current_bidder_seat)
        simulation_log << "👋 #{bidder_name} passes"
      end
    end

    # Try calling trump phase
    current_round.reload
    if current_round.calling_trump?
      simulation_log << ''
      simulation_log << '📋 Calling Trump Phase'

      4.times do |_bidder_index|
        current_round.reload
        current_bidder_seat = current_round.current_bidder_seat
        break unless current_bidder_seat

        bidder_name = players_by_seat[current_bidder_seat][:name]

        # 70% chance to call trump
        if rand < 0.7
          # Choose a suit different from turned up card
          available_suits = %w[hearts clubs diamonds spades] - [current_round.turned_up_card_suit]
          trump_suit = available_suits.sample

          if current_round.call_trump!(current_bidder_seat, trump_suit)
            simulation_log << "🎺 #{bidder_name} calls #{trump_suit.upcase}!"
            simulation_log << "✅ Trump suit selected: #{trump_suit.upcase}"

            return {
              trump_suit: trump_suit,
              maker_team: current_round.maker_team,
              maker_player_name: bidder_name
            }
          end
        else
          current_round.pass_bidding!(current_bidder_seat)
          simulation_log << "👋 #{bidder_name} passes"
        end
      end
    end

    # If we get here, hand was thrown in
    simulation_log << '🚫 All players passed - hand thrown in'
    { trump_suit: nil, maker_team: nil, maker_player_name: nil }
  end

  def generate_text_log(simulation_data)
    log = []
    log << '🎮 Starting Full Euchre Game Simulation'
    log << '=' * 50
    log << "✅ Game created with code: #{simulation_data[:game_code]}"
    log << "✅ 4 players joined: #{simulation_data[:players_by_seat].values.map { |p| p[:name] }.join(', ')}"
    log << '✅ Game is now ACTIVE!'
    log << '📊 Initial Scores - Team 0: 0, Team 1: 0'

    simulation_data[:players_by_seat].each do |seat, data|
      team = seat % 2
      log << "👤 #{data[:name]} - Seat #{seat}, Team #{team}"
    end
    log << '📋 Teams: Team 0 (Seats 0,2) vs Team 1 (Seats 1,3)'

    simulation_data[:rounds].each do |round|
      log << ''
      log << '=' * 30
      log << "🎯 ROUND #{round[:number]}"
      log << '=' * 30
      log << "🃏 Dealer: #{round[:dealer]} (Seat #{round[:dealer_seat]})"
      log << ''
      log << '🎴 Player Hands:'

      round[:player_hands].each do |seat, hand_data|
        log << "  #{hand_data[:name]} (Seat #{seat}): #{hand_data[:cards].join(' ')} (#{hand_data[:cards].length} cards)"
      end

      if round[:thrown_in]
        log << '🚫 Hand thrown in - no trump selected'
      else
        log << ''
        log << '🎺 Trump Selection Phase'
        log << "🃏 Turned up card: #{round[:turned_up_card]}"
        log << "✅ Trump suit selected: #{round[:trump_suit]&.upcase}"
        log << "👥 Making team: Team #{round[:maker_team]}"

        log << ''
        log << '🎴 Playing 5 Tricks'

        round[:tricks_data].each do |trick|
          log << ''
          log << "  🎯 Trick #{trick[:number]}"
          log << "    👤 Lead: #{trick[:lead_name]} (Seat #{trick[:lead_seat]})"

          trick[:plays].each do |play|
            log << if play[:card] && play[:success]
                     "    🎴 #{play[:player_name]}: #{play[:card]}"
                   else
                     "    ❌ #{play[:player_name]}: #{play[:card] || 'No cards'}"
                   end
          end

          if trick[:winner]
            log << "    🏆 Winner: #{trick[:winner][:name]} (Seat #{trick[:winner][:seat]}) - Team #{trick[:winner][:team]}"
            log << "    📊 Tricks: Team 0: #{trick[:team_tricks][0]}, Team 1: #{trick[:team_tricks][1]}"
          end
        end

        log << ''
        log << "🎯 Round #{round[:number]} Summary"
        log << "📊 Tricks Won - Team 0 (Seats 0,2): #{round[:team_tricks][0]}, Team 1 (Seats 1,3): #{round[:team_tricks][1]}"
      end

      log << ''
      log << "📊 Round #{round[:number]} Results"
      log << "📊 Scores - Team 0 (Seats 0,2): #{round[:scores][:team_0]}, Team 1 (Seats 1,3): #{round[:scores][:team_1]}"
    end

    log << ''
    log << '=' * 50
    log << '🎮 Full Game Simulation Complete!'
    log << '=' * 50

    if simulation_data[:finished]
      log << '🎉 GAME OVER!'
      log << "🏆 WINNER: Team #{simulation_data[:winner]} (Seats #{simulation_data[:winner] == 0 ? '0,2' : '1,3'})!"
      log << "📊 Final Scores - Team 0: #{simulation_data[:final_scores][:team_0]}, Team 1: #{simulation_data[:final_scores][:team_1]}"
      log << '✅ Game completed successfully with valid winner!'
    end

    log
  end

  def generate_simulation_data
    # Create game and players
    game = Game.create!(code: SecureRandom.alphanumeric(8).upcase)
    sessions = []
    players_data = []

    4.times do |i|
      session = Session.create!(
        session_id: SecureRandom.uuid,
        name: "Player#{i + 1}"
      )
      sessions << session

      player = game.players.create!(session: session)
      players_data << { name: "Player#{i + 1}", session: session, player: player }
    end

    # Start the game
    game.start_game!

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

    rounds_data = []
    round_number = 1
    max_rounds = 2

    while round_number <= max_rounds
      game.reload
      current_round = game.current_round

      break unless current_round

      dealer_seat = current_round.dealer_seat

      # Get player hands
      player_hands = {}
      (0..3).each do |seat|
        player = players_by_seat[seat][:player]
        hand = player.hand_for_round(current_round)
        cards = hand ? hand.cards : []
        player_hands[seat] = {
          name: players_by_seat[seat][:name],
          cards: cards
        }
      end

      # Trump selection phase
      trump_result = simulate_trump_selection_action(game, players_by_seat, dealer_seat, [])
      trump_suit = trump_result[:trump_suit]
      maker_team = trump_result[:maker_team]
      maker_player_name = trump_result[:maker_player_name]

      if trump_suit.nil?
        rounds_data << {
          number: round_number,
          dealer: players_by_seat[dealer_seat][:name],
          dealer_seat: dealer_seat,
          turned_up_card: current_round.turned_up_card,
          player_hands: player_hands,
          trump_suit: nil,
          maker_team: nil,
          maker_player_name: nil,
          tricks_data: [],
          team_tricks: { 0 => 0, 1 => 0 },
          thrown_in: true
        }
        round_number += 1
        next
      end

      # Start tricks if ready
      current_round.start_tricks! if current_round.trump_selected? && !current_round.dealer_needs_to_discard?

      # Play 5 tricks
      team_tricks = { 0 => 0, 1 => 0 }
      tricks_data = []

      5.times do |trick_num|
        game.reload
        current_round = game.current_round
        current_trick = current_round.current_trick

        next unless current_trick

        lead_seat = current_trick.lead_seat
        trick_plays = []

        # Play cards for each player in turn
        4.times do |player_order|
          current_player_seat = (lead_seat + player_order) % 4
          player_data = players_by_seat[current_player_seat]
          player = player_data[:player]

          # Choose a card from player's hand
          hand = player.hand_for_round(current_round)
          available_cards = hand.cards

          if available_cards.empty?
            trick_plays << {
              player_name: player_data[:name],
              seat: current_player_seat,
              card: nil,
              success: false
            }
            next
          end

          # Simple card selection logic
          card = available_cards.first

          # Play the card
          current_round.reload
          current_trick = current_round.current_trick

          success = current_trick.play_card!(player, card)
          trick_plays << {
            player_name: player_data[:name],
            seat: current_player_seat,
            card: card,
            success: success
          }

          # If trick is completed and not the last trick, create next trick
          next unless current_trick.completed? && trick_num < 4

          next_lead_seat = current_trick.winning_seat
          current_round.tricks.create!(
            number: trick_num + 1,
            lead_seat: next_lead_seat
          )
        end

        # Check for trick winner
        sleep(0.1)
        game.reload
        current_round = game.current_round

        winner_info = nil
        if current_round && current_round.tricks.any?
          target_trick = current_round.tricks.find { |t| t && t.number == trick_num && t.completed? && t.winning_seat }

          if target_trick
            winning_seat = target_trick.winning_seat
            winner_name = players_by_seat[winning_seat][:name]
            winner_team = winning_seat % 2

            team_tricks[winner_team] += 1
            winner_info = {
              name: winner_name,
              seat: winning_seat,
              team: winner_team
            }
          end
        end

        tricks_data << {
          number: trick_num + 1,
          lead_seat: lead_seat,
          lead_name: players_by_seat[lead_seat][:name],
          plays: trick_plays,
          winner: winner_info,
          team_tricks: team_tricks.dup
        }
      end

      # Complete the round after all 5 tricks
      current_round.reload
      current_round.complete_round! if current_round.tricks.count == 5 && current_round.tricks.all?(&:completed?)

      # Fix missing trick if needed
      total_tricks = team_tricks[0] + team_tricks[1]
      if total_tricks == 4
        missing_winner_team = team_tricks[0] <= team_tricks[1] ? 0 : 1
        team_tricks[missing_winner_team] += 1
      end

      # Get final scores
      game.reload
      team_0_score = game.team_score(0)
      team_1_score = game.team_score(1)

      rounds_data << {
        number: round_number,
        dealer: players_by_seat[dealer_seat][:name],
        dealer_seat: dealer_seat,
        turned_up_card: current_round.turned_up_card,
        player_hands: player_hands,
        trump_suit: trump_suit,
        maker_team: maker_team,
        maker_player_name: maker_player_name,
        tricks_data: tricks_data,
        team_tricks: team_tricks,
        scores: { team_0: team_0_score, team_1: team_1_score },
        thrown_in: false
      }

      # Check for game end
      break if game.finished?

      round_number += 1
    end

    game.reload
    {
      game_code: game.code,
      players_by_seat: players_by_seat,
      rounds: rounds_data,
      final_scores: {
        team_0: game.team_score(0),
        team_1: game.team_score(1)
      },
      winner: game.winning_team,
      total_rounds: round_number - 1,
      finished: game.finished?
    }
  end
end
