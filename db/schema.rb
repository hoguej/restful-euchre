# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_250_726_121_517) do
  create_table 'card_plays', force: :cascade do |t|
    t.integer 'trick_id', null: false
    t.integer 'player_id', null: false
    t.string 'card', null: false
    t.integer 'play_order', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['player_id'], name: 'index_card_plays_on_player_id'
    t.index %w[trick_id play_order], name: 'index_card_plays_on_trick_id_and_play_order', unique: true
    t.index ['trick_id'], name: 'index_card_plays_on_trick_id'
  end

  create_table 'games', force: :cascade do |t|
    t.string 'code', null: false
    t.string 'state', default: 'waiting'
    t.integer 'winning_team'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['code'], name: 'index_games_on_code', unique: true
  end

  create_table 'player_hands', force: :cascade do |t|
    t.integer 'player_id', null: false
    t.integer 'round_id', null: false
    t.text 'cards'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[player_id round_id], name: 'index_player_hands_on_player_id_and_round_id', unique: true
    t.index ['player_id'], name: 'index_player_hands_on_player_id'
    t.index ['round_id'], name: 'index_player_hands_on_round_id'
  end

  create_table 'players', force: :cascade do |t|
    t.integer 'game_id', null: false
    t.integer 'session_id', null: false
    t.integer 'seat'
    t.integer 'team'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[game_id seat], name: 'index_players_on_game_id_and_seat', unique: true, where: 'seat IS NOT NULL'
    t.index %w[game_id session_id], name: 'index_players_on_game_id_and_session_id', unique: true
    t.index ['game_id'], name: 'index_players_on_game_id'
    t.index ['session_id'], name: 'index_players_on_session_id'
  end

  create_table 'rounds', force: :cascade do |t|
    t.integer 'game_id', null: false
    t.integer 'number', null: false
    t.integer 'dealer_seat', null: false
    t.string 'trump_suit'
    t.integer 'maker_team'
    t.boolean 'loner', default: false
    t.integer 'winning_team'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'turned_up_card'
    t.string 'trump_selection_phase', default: 'ordering_up'
    t.boolean 'ordered_up', default: false
    t.integer 'current_bidder_seat'
    t.index ['current_bidder_seat'], name: 'index_rounds_on_current_bidder_seat'
    t.index %w[game_id number], name: 'index_rounds_on_game_id_and_number', unique: true
    t.index ['game_id'], name: 'index_rounds_on_game_id'
  end

  create_table 'sessions', force: :cascade do |t|
    t.string 'session_id', null: false
    t.string 'name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['session_id'], name: 'index_sessions_on_session_id', unique: true
  end

  create_table 'tricks', force: :cascade do |t|
    t.integer 'round_id', null: false
    t.integer 'number', null: false
    t.integer 'lead_seat', null: false
    t.integer 'winning_seat'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[round_id number], name: 'index_tricks_on_round_id_and_number', unique: true
    t.index ['round_id'], name: 'index_tricks_on_round_id'
  end

  add_foreign_key 'card_plays', 'players'
  add_foreign_key 'card_plays', 'tricks'
  add_foreign_key 'player_hands', 'players'
  add_foreign_key 'player_hands', 'rounds'
  add_foreign_key 'players', 'games'
  add_foreign_key 'players', 'sessions'
  add_foreign_key 'rounds', 'games'
  add_foreign_key 'tricks', 'rounds'
end
