class CreateCardPlays < ActiveRecord::Migration[8.0]
  def change
    create_table :card_plays do |t|
      t.references :trick, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :card, null: false
      t.integer :play_order, null: false

      t.timestamps
    end

    add_index :card_plays, [:trick_id, :play_order], unique: true
  end
end 