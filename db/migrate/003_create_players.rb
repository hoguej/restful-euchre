class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.references :game, null: false, foreign_key: true
      t.references :session, null: false, foreign_key: true
      t.integer :seat
      t.integer :team

      t.timestamps
    end

    add_index :players, %i[game_id session_id], unique: true
    add_index :players, %i[game_id seat], unique: true, where: 'seat IS NOT NULL'
  end
end
