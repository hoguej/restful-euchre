class CreatePlayerHands < ActiveRecord::Migration[8.0]
  def change
    create_table :player_hands do |t|
      t.references :player, null: false, foreign_key: true
      t.references :round, null: false, foreign_key: true
      t.text :cards, null: false

      t.timestamps

      # Ensure one hand per player per round
      t.index %i[player_id round_id], unique: true
    end
  end
end
