class GamesController < ApplicationController
  before_action :set_game, only: [:show, :join, :action, :players]

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
    if @game.finished?
      return render json: { error: "Game has finished" }, status: :forbidden
    end

    if @game.full?
      return render json: { error: "Game is full" }, status: :forbidden
    end

    # Check if player already in game
    existing_player = @game.players.find_by(session: current_session)
    if existing_player
      return render json: { 
        message: "Already in game",
        player: player_json(existing_player)
      }
    end

    # Update session name if provided
    if params[:name].present?
      current_session.update!(name: params[:name])
    end

    # Create player
    player = @game.players.build(session: current_session)
    
    if player.save
      # Start game if we now have 4 players
      if @game.can_start?
        @game.start_game!
      end

      render json: {
        message: "Joined game successfully",
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
    
    unless player
      return render json: { error: "Not in this game" }, status: :forbidden
    end

    unless @game.active?
      return render json: { error: "Game is not active" }, status: :forbidden
    end

    case params[:action_type]
    when 'play_card'
      handle_play_card(player)
    when 'call_trump'
      handle_call_trump(player)
    when 'pass'
      handle_pass(player)
    else
      render json: { error: "Invalid action type" }, status: :bad_request
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
    render json: { error: "Game not found" }, status: :not_found
  end

  def handle_play_card(player)
    round = @game.current_round
    trick = round&.current_trick
    card = params[:card]

    unless trick
      return render json: { error: "No active trick" }, status: :bad_request
    end

    unless card.present?
      return render json: { error: "Card is required" }, status: :bad_request
    end

    if trick.play_card!(player, card)
      # Check if trick is complete
      if trick.completed?
        # Create next trick or complete round
        if trick.number < 4
          next_trick = round.tricks.create!(
            number: trick.number + 1,
            lead_seat: trick.winning_seat
          )
        else
          round.complete_round!
        end
      end

      render json: {
        message: "Card played successfully",
        trick: trick_json(trick),
        game: game_json(@game)
      }
    else
      render json: { error: "Invalid card play" }, status: :bad_request
    end
  end

  def handle_call_trump(player)
    round = @game.current_round
    trump_suit = params[:trump_suit]

    unless Round::SUITS.include?(trump_suit)
      return render json: { error: "Invalid trump suit" }, status: :bad_request
    end

    if round.update(trump_suit: trump_suit, maker_team: player.team, loner: params[:loner] || false)
      # Create first trick
      round.tricks.create!(number: 0, lead_seat: (round.dealer_seat + 1) % 4)
      
      render json: {
        message: "Trump called successfully",
        round: round_json(round)
      }
    else
      render json: { errors: round.errors }, status: :unprocessable_entity
    end
  end

  def handle_pass(player)
    # Implementation for passing would go here
    # This would involve tracking who has passed and moving to next player
    render json: { message: "Passed" }
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