class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :code, null: false, index: { unique: true }
      t.string :state, default: 'waiting'
      t.integer :winning_team

      t.timestamps
    end
  end
end
