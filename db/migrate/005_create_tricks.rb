class CreateTricks < ActiveRecord::Migration[8.0]
  def change
    create_table :tricks do |t|
      t.references :round, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :lead_seat, null: false
      t.integer :winning_seat

      t.timestamps
    end

    add_index :tricks, %i[round_id number], unique: true
  end
end
