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

  private

  def set_game
    @game = Game.find_by!(code: params[:code])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Game not found' }, status: :not_found
  end

  def handle_play_card(player)
    card = params[:card]

    return render json: { error: 'Card is required' }, status: :bad_request unless card.present?

    round = @game.current_round

    return render json: { error: 'No active round' }, status: :bad_request unless round

    current_trick = round.current_trick

    return render json: { error: 'No active trick' }, status: :bad_request unless current_trick

    return render json: { error: 'Not your turn' }, status: :forbidden unless current_trick.can_play_card?(player.seat)

    if current_trick.play_card!(player, card)
      # If trick is completed and we have more tricks to play, create the next trick
      begin
        if current_trick.completed? && !round.completed?
          # Check if we need to create another trick or complete the round
          trick_count = round.tricks.count

          if trick_count < 5
            # Create the next trick with the winner of this trick as lead
            round.tricks.create!(
              number: trick_count,
              lead_seat: current_trick.winning_seat
            )
          else
            # All 5 tricks are done, complete the round
            return render json: { error: 'Failed to complete round' }, status: :bad_request unless round.complete_round!
          end
        end
      rescue StandardError => e
        Rails.logger.error "Error completing trick/round: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return render json: { error: 'Game state error' }, status: :internal_server_error
      end

      render json: {
        message: 'Card played successfully',
        game: game_json(@game),
        current_round: current_round_json,
        player_hand: current_player_hand_json(player)
      }
    else
      render json: { error: 'Invalid card play' }, status: :bad_request
    end
  end

  def handle_order_up(player)
    round = @game.current_round

    return render json: { error: 'No active round' }, status: :bad_request unless round

    return render json: { error: 'Not ordering up phase' }, status: :bad_request unless round.ordering_up?

    unless round.current_bidder_seat == player.seat
      return render json: { error: 'Not your turn to bid' },
                    status: :forbidden
    end

    if round.order_up!(player.seat)
      render json: {
        message: 'Trump ordered up successfully',
        round: round_json(round)
      }
    else
      render json: { error: 'Failed to order up' }, status: :bad_request
    end
  end

  def handle_call_trump(player)
    trump_suit = params[:trump_suit]

    return render json: { error: 'Trump suit is required' }, status: :bad_request unless trump_suit.present?

    # Validate trump suit before proceeding
    valid_suits = %w[hearts diamonds clubs spades]
    return render json: { error: 'Invalid trump suit' }, status: :bad_request unless valid_suits.include?(trump_suit)

    round = @game.current_round

    return render json: { error: 'No active round' }, status: :bad_request unless round

    return render json: { error: 'Not calling trump phase' }, status: :bad_request unless round.calling_trump?

    unless round.current_bidder_seat == player.seat
      return render json: { error: 'Not your turn to bid' },
                    status: :forbidden
    end

    if round.call_trump!(player.seat, trump_suit)
      render json: {
        message: 'Trump called successfully',
        round: round_json(round)
      }
    else
      render json: { error: 'Failed to call trump' }, status: :bad_request
    end
  end

  def handle_pass(player)
    round = @game.current_round

    return render json: { error: 'No active round' }, status: :bad_request unless round

    unless round.ordering_up? || round.calling_trump?
      return render json: { error: 'Not bidding phase' },
                    status: :bad_request
    end

    unless round.current_bidder_seat == player.seat
      return render json: { error: 'Not your turn to bid' },
                    status: :forbidden
    end

    if round.pass_bidding!(player.seat)
      render json: {
        message: 'Passed successfully',
        round: round_json(round)
      }
    else
      render json: { error: 'Failed to pass' }, status: :bad_request
    end
  end

  def handle_discard_card(player)
    card = params[:card]

    return render json: { error: 'Card is required' }, status: :bad_request unless card.present?

    round = @game.current_round

    return render json: { error: 'No active round' }, status: :bad_request unless round

    unless round.dealer_needs_to_discard?
      return render json: { error: 'Not dealer discard phase' },
                    status: :bad_request
    end

    return render json: { error: 'Not the dealer' }, status: :forbidden unless round.dealer_seat == player.seat

    if round.dealer_discard!(player, card)
      render json: {
        message: 'Card discarded successfully',
        round: round_json(round),
        player_hand: current_player_hand_json(player)
      }
    else
      render json: { error: 'Failed to discard card' }, status: :bad_request
    end
  end

  # JSON helper methods
  def game_json(game)
    {
      id: game.id,
      code: game.code,
      state: game.state,
      created_at: game.created_at,
      player_count: game.players.count,
      winning_team: game.winning_team
    }
  end

  def current_player_json
    return nil unless current_session

    player = @game.players.find_by(session: current_session)
    return nil unless player

    player_json(player)
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
    return nil unless @game.current_round

    round_json(@game.current_round)
  end

  def round_json(round)
    {
      id: round.id,
      number: round.number,
      dealer_seat: round.dealer_seat,
      trump_suit: round.trump_suit,
      trump_selection_phase: round.trump_selection_phase,
      current_bidder_seat: round.current_bidder_seat,
      turned_up_card: round.turned_up_card,
      maker_team: round.maker_team,
      loner: round.loner,
      winning_team: round.winning_team,
      completed: round.completed?,
      points_scored: round.points_scored,
      scoring_reason: round.scoring_reason,
      tricks: round.tricks.includes(:card_plays).map do |trick|
        {
          id: trick.id,
          number: trick.number,
          lead_seat: trick.lead_seat,
          winning_seat: trick.winning_seat,
          completed: trick.completed?,
          cards_played: trick.card_plays.in_order.map do |play|
            {
              player_seat: play.player.seat,
              card: play.card,
              play_order: play.play_order
            }
          end
        }
      end
    }
  end

  def current_player_hand_json(player)
    return [] unless @game.current_round

    hand = player.hand_for_round(@game.current_round)
    hand&.cards || []
  end

  def current_session
    session_id = cookies[:session_id]
    return nil unless session_id

    @current_session ||= Session.find_by(session_id: session_id)
  end
end
