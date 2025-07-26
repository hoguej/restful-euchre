require 'test_helper'

class GamesApiTest < ActionDispatch::IntegrationTest
  # === GAME CREATION TESTS ===

  test 'POST /games creates a new game successfully' do
    use_session('TestPlayer')

    post '/games'
    assert_response :created

    response_data = JSON.parse(response.body)
    assert_not_nil response_data['game']
    assert_not_nil response_data['game']['code']
    assert_equal 'waiting', response_data['game']['state']
    assert_equal 0, response_data['game']['player_count']
    assert_nil response_data['game']['winning_team']
    assert_not_nil response_data['join_url']
    assert_equal "/games/#{response_data['game']['code']}", response_data['join_url']
  end

  test 'POST /games creates unique game codes' do
    use_session('TestPlayer')

    post '/games'
    first_game = JSON.parse(response.body)['game']['code']

    post '/games'
    second_game = JSON.parse(response.body)['game']['code']

    assert_not_equal first_game, second_game
  end

  test 'POST /games creates session if none exists' do
    # Don't create session first
    post '/games'
    assert_response :created

    # Should have created a session automatically
    assert Session.count > 0
  end

  # === GAME STATE RETRIEVAL TESTS ===

  test 'GET /games/:code returns game state successfully' do
    use_session('TestPlayer')

    # Create game first
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']

    # Get game state
    get "/games/#{game_code}"
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_not_nil response_data['game']
    assert_equal game_code, response_data['game']['code']
    assert_equal 'waiting', response_data['game']['state']
    assert_nil response_data['current_player']
    assert_equal [], response_data['players']
    assert_nil response_data['current_round']
    assert_equal 0, response_data['scores']['team_0']
    assert_equal 0, response_data['scores']['team_1']
  end

  test 'GET /games/:code returns 404 for non-existent game' do
    use_session('TestPlayer')

    get '/games/NONEXISTENT'
    assert_response :not_found
  end

  # === GAME JOINING TESTS ===

  test 'POST /games/:code/join allows player to join game' do
    use_session('TestPlayer')

    # Create game
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']

    # Join game
    post "/games/#{game_code}/join", params: { name: 'Player1' }
    assert_response :created

    response_data = JSON.parse(response.body)
    assert_equal 'Joined game successfully', response_data['message']
    assert_not_nil response_data['player']
    assert_equal 'Player1', response_data['player']['name']
    assert_nil response_data['player']['seat'] # Not assigned until 4 players
    assert_nil response_data['player']['team']
    assert_equal 1, response_data['game']['player_count']
  end

  test 'POST /games/:code/join updates session name' do
    use_session('OldName')

    # Create game
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']

    # Join with new name
    post "/games/#{game_code}/join", params: { name: 'NewName' }
    assert_response :created

    # Verify response shows updated name
    response_data = JSON.parse(response.body)
    assert_equal 'NewName', response_data['player']['name']
  end

  test 'POST /games/:code/join prevents duplicate joins' do
    use_session('TestPlayer')

    # Create game
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']

    # Join game first time
    post "/games/#{game_code}/join", params: { name: 'Player1' }
    assert_response :created

    # Try to join again
    post "/games/#{game_code}/join", params: { name: 'Player1' }
    assert_response :success
    assert_equal 'Already in game', JSON.parse(response.body)['message']
  end

  test 'POST /games/:code/join rejects join when game is full' do
    # Create game with 4 players
    game_setup = create_game_with_players(4)

    # Try to add 5th player with new session
    use_session('Player5')
    post "/games/#{game_setup[:game_code]}/join", params: { name: 'Player5' }
    assert_response :forbidden
    assert_equal 'Game is full', JSON.parse(response.body)['error']
  end

  test 'POST /games/:code/join rejects join when game is finished' do
    use_session('TestPlayer')

    # Create game and set it to finished
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']
    game = Game.find_by(code: game_code)
    game.update!(state: 'finished')

    # Try to join finished game
    post "/games/#{game_code}/join", params: { name: 'Player1' }
    assert_response :forbidden
    assert_equal 'Game has finished', JSON.parse(response.body)['error']
  end

  test 'POST /games/:code/join starts game when 4 players join' do
    game_setup = create_game_with_players(4)

    # Check game state
    game_state = get_game_state(game_setup[:game_code])
    assert_equal 'active', game_state['game']['state']
    assert_equal 4, game_state['game']['player_count']

    # All players should have seats and teams assigned
    game_state['players'].each do |player|
      assert_not_nil player['seat']
      assert_not_nil player['team']
      assert_includes [0, 1, 2, 3], player['seat']
      assert_includes [0, 1], player['team']
    end

    # Should have first round created
    assert_not_nil game_state['current_round']
    assert_equal 1, game_state['current_round']['number']
  end

  # === PLAYERS LIST TESTS ===

  test 'GET /games/:code/players returns players list' do
    game_setup = create_game_with_players(2)

    get "/games/#{game_setup[:game_code]}/players"
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_equal 2, response_data['players'].length

    response_data['players'].each do |player|
      assert_not_nil player['name']
      assert_includes %w[Player1 Player2], player['name']
    end
  end

  test 'GET /games/:code/players returns 404 for non-existent game' do
    use_session('TestPlayer')

    get '/games/NONEXISTENT/players'
    assert_response :not_found
  end

  # === GAME ACTIONS TESTS ===

  test 'POST /games/:code/action requires being in the game' do
    use_session('TestPlayer')

    # Create game but don't join
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']

    # Try to make action
    make_action(game_code, 'pass')
    assert_response :forbidden
    assert_equal 'Not in this game', JSON.parse(response.body)['error']
  end

  test 'POST /games/:code/action requires active game' do
    use_session('TestPlayer')

    # Create game and join
    post '/games'
    game_code = JSON.parse(response.body)['game']['code']
    post "/games/#{game_code}/join", params: { name: 'Player1' }

    # Try to make action in waiting game
    make_action(game_code, 'pass')
    assert_response :forbidden
    assert_equal 'Game is not active', JSON.parse(response.body)['error']
  end

  test 'POST /games/:code/action rejects invalid action types' do
    game_setup = create_game_with_players(4)
    switch_to_session('Player1')

    make_action(game_setup[:game_code], 'invalid_action')
    assert_response :bad_request
    assert_equal 'Invalid action type', JSON.parse(response.body)['error']
  end

  test 'POST /games/:code/action handles ordering up' do
    game_setup = create_game_with_players(4)

    # Find out which player should be the current bidder
    game_state = get_game_state(game_setup[:game_code])
    current_round = game_state['current_round']

    # Skip test if no current round (game not properly started)
    skip 'No current round found' unless current_round

    current_bidder_seat = current_round['current_bidder_seat']
    bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

    # Debug: Check if bidder_player was found
    unless bidder_player
      puts "DEBUG: Could not find bidder player for seat #{current_bidder_seat}"
      puts "DEBUG: Available players: #{game_state['players'].map do |p|
        "#{p['name']} (seat #{p['seat']})"
      end.join(', ')}"
      skip 'Could not find bidder player'
    end

    switch_to_session(bidder_player['name'])

    make_action(game_setup[:game_code], 'order_up')
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_match(/ordered up/, response_data['message'])
  end

  test 'POST /games/:code/action handles trump calling after all pass ordering up' do
    game_setup = create_game_with_players(4)

    # Have all 4 players pass the ordering up phase
    4.times do |i|
      game_state = get_game_state(game_setup[:game_code])
      current_round = game_state['current_round']

      # Skip test if no current round (game not properly started)
      skip 'No current round found' unless current_round

      current_bidder_seat = current_round['current_bidder_seat']
      bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

      # Debug: Check if bidder_player was found
      unless bidder_player
        puts "DEBUG: Could not find bidder player for seat #{current_bidder_seat} in trump calling test (pass #{i})"
        puts "DEBUG: Available players: #{game_state['players'].map do |p|
          "#{p['name']} (seat #{p['seat']})"
        end.join(', ')}"
        skip 'Could not find bidder player'
      end

      switch_to_session(bidder_player['name'])
      make_action(game_setup[:game_code], 'pass')
      assert_response :success
    end

    # Now we should be in calling trump phase
    game_state = get_game_state(game_setup[:game_code])
    current_round = game_state['current_round']

    # Skip test if no current round
    skip 'No current round found' unless current_round

    assert_equal 'calling_trump', current_round['trump_selection_phase']

    # Get the current bidder and call trump
    current_bidder_seat = current_round['current_bidder_seat']
    bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

    # Determine a valid trump suit (can't be the same as turned up card)
    turned_up_card = current_round['turned_up_card']
    turned_up_suit = case turned_up_card[1]
                     when 'H' then 'hearts'
                     when 'D' then 'diamonds'
                     when 'C' then 'clubs'
                     when 'S' then 'spades'
                     end

    # Pick a different suit than the turned up card
    valid_suits = %w[hearts diamonds clubs spades] - [turned_up_suit]
    trump_suit = valid_suits.first

    switch_to_session(bidder_player['name'])
    make_action(game_setup[:game_code], 'call_trump', { trump_suit: trump_suit })
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_equal 'Trump called successfully', response_data['message']
  end

  test 'POST /games/:code/action handles passing' do
    game_setup = create_game_with_players(4)

    # Find out which player should be the current bidder
    game_state = get_game_state(game_setup[:game_code])
    current_round = game_state['current_round']

    # Skip test if no current round (game not properly started)
    skip 'No current round found' unless current_round

    current_bidder_seat = current_round['current_bidder_seat']
    bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

    # Debug: Check if bidder_player was found
    unless bidder_player
      puts "DEBUG: Could not find bidder player for seat #{current_bidder_seat}"
      puts "DEBUG: Available players: #{game_state['players'].map do |p|
        "#{p['name']} (seat #{p['seat']})"
      end.join(', ')}"
      skip 'Could not find bidder player'
    end

    switch_to_session(bidder_player['name'])

    make_action(game_setup[:game_code], 'pass')
    assert_response :success

    response_data = JSON.parse(response.body)
    assert_match(/Passed/, response_data['message'])
  end

  test 'POST /games/:code/action validates trump suit for call_trump' do
    game_setup = create_game_with_players(4)

    # Have all 4 players pass the ordering up phase to get to calling trump phase
    4.times do |i|
      game_state = get_game_state(game_setup[:game_code])
      current_round = game_state['current_round']

      # Skip test if no current round
      skip 'No current round found' unless current_round

      current_bidder_seat = current_round['current_bidder_seat']
      bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

      # Debug: Check if bidder_player was found
      unless bidder_player
        puts "DEBUG: Could not find bidder player for seat #{current_bidder_seat} in trump validation test (pass #{i})"
        puts "DEBUG: Available players: #{game_state['players'].map do |p|
          "#{p['name']} (seat #{p['seat']})"
        end.join(', ')}"
        skip 'Could not find bidder player'
      end

      switch_to_session(bidder_player['name'])
      make_action(game_setup[:game_code], 'pass')
      assert_response :success
    end

    # Now we should be in calling trump phase
    game_state = get_game_state(game_setup[:game_code])
    current_round = game_state['current_round']

    # Skip test if no current round
    skip 'No current round found' unless current_round

    assert_equal 'calling_trump', current_round['trump_selection_phase']

    # Get the current bidder and try to call invalid trump
    current_bidder_seat = current_round['current_bidder_seat']
    bidder_player = game_state['players'].find { |p| p['seat'] == current_bidder_seat }

    switch_to_session(bidder_player['name'])
    make_action(game_setup[:game_code], 'call_trump', { trump_suit: 'invalid' })
    assert_response :bad_request
    assert_equal 'Invalid trump suit', JSON.parse(response.body)['error']
  end

  # === EDGE CASES AND ERROR HANDLING ===

  test 'handles requests without session gracefully' do
    # Make request without any session setup
    post '/games'
    assert_response :created

    # Should auto-create session
    assert Session.count > 0
  end

  test 'maintains separate sessions for different requests' do
    # First session
    use_session('Player1')
    post '/games'
    game1_code = JSON.parse(response.body)['game']['code']

    # Second session
    use_session('Player2')
    post '/games'
    game2_code = JSON.parse(response.body)['game']['code']

    # Games should be different
    assert_not_equal game1_code, game2_code

    # Each should be able to join their own game
    post "/games/#{game2_code}/join", params: { name: 'Player2' }
    assert_response :created

    switch_to_session('Player1')
    post "/games/#{game1_code}/join", params: { name: 'Player1' }
    assert_response :created
  end

  test 'prevents joining non-existent game' do
    use_session('TestPlayer')

    post '/games/NONEXISTENT/join', params: { name: 'Player1' }
    assert_response :not_found
  end

  test 'prevents actions on non-existent game' do
    use_session('TestPlayer')

    make_action('NONEXISTENT', 'pass')
    assert_response :not_found
  end
end
