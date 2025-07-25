class CreateRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :rounds do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :dealer_seat, null: false
      t.string :trump_suit
      t.integer :maker_team
      t.boolean :loner, default: false
      t.integer :winning_team

      t.timestamps
    end

    add_index :rounds, [:game_id, :number], unique: true
  end
end 