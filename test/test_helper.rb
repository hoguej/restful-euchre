ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  def setup
    @session_cookies = {}
  end

  # Helper method to simulate having a session by setting cookies
  def use_session(name = "TestPlayer#{rand(1000)}")
    session_id = SecureRandom.uuid
    cookies[:session_id] = session_id
    @session_cookies[name] = session_id
    session_id
  end

  # Helper to switch between different player sessions
  def switch_to_session(session_name)
    return unless @session_cookies[session_name]

    cookies[:session_id] = @session_cookies[session_name]
  end

  # Helper to create a game with players
  def create_game_with_players(player_count = 4)
    # Create game with first session
    use_session('Player1')
    post '/games'
    assert_response :created
    game_data = JSON.parse(response.body)
    game_code = game_data['game']['code']

    players = []

    # Add players
    player_count.times do |i|
      session_id = use_session("Player#{i + 1}")

      post "/games/#{game_code}/join", params: { name: "Player#{i + 1}" }
      assert_response :created

      player_data = JSON.parse(response.body)['player']
      players << {
        session_id: session_id,
        data: player_data
      }
    end

    # Ensure game is properly started with a current round and seat assignments
    3.times do |attempt|
      get "/games/#{game_code}"
      assert_response :success
      game_state = JSON.parse(response.body)

      # Check if game is active, has current round, and all players have seats
      all_players_have_seats = game_state['players']&.all? { |p| p['seat'] }

      if game_state['game']['state'] == 'active' &&
         game_state['current_round'] &&
         all_players_have_seats
        break
      end

      # Wait a bit and try again - timing issue with seat assignment
      sleep(0.01) if attempt < 2
    end

    { game_code: game_code, players: players }
  end

  # Helper to get current game state
  def get_game_state(game_code)
    get "/games/#{game_code}"
    assert_response :success
    JSON.parse(response.body)
  end

  # Helper to make a game action
  def make_action(game_code, action_type, params = {})
    post "/games/#{game_code}/action", params: { action_type: action_type }.merge(params)
  end

  # Helper to generate a random turned up card for tests
  def generate_test_card
    ranks = %w[9 T J Q K A]
    suits = %w[H D C S]
    "#{ranks.sample}#{suits.sample}"
  end
end
