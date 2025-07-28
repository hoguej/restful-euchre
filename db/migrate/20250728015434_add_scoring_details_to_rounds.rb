class AddScoringDetailsToRounds < ActiveRecord::Migration[8.0]
  def change
    add_column :rounds, :points_scored, :integer
    add_column :rounds, :scoring_reason, :string
  end
end
