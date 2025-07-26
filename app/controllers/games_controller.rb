class GamesController < ApplicationController
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
    render json: {
      game: game_json(@game),
      current_player: current_player_json,
      players: players_json(@game.players.by_seat),
      current_round: current_round_json,
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
        # Create next trick or complete round
        if trick.number < 4
          round.tricks.create!(
            number: trick.number + 1,
            lead_seat: trick.winning_seat
          )
        else
          round.complete_round!
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

    # For now, just start the tricks after discard
    # In a full implementation, we'd track the dealer's hand
    if round.start_tricks!
      render json: {
        message: 'Card discarded - tricks starting',
        round: round_json(round),
        game: game_json(@game)
      }
    else
      render json: { error: 'Failed to start tricks' }, status: :bad_request
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
end
