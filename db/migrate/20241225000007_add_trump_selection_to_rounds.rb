class AddTrumpSelectionToRounds < ActiveRecord::Migration[8.0]
  def change
    add_column :rounds, :turned_up_card, :string
    add_column :rounds, :trump_selection_phase, :string, default: 'ordering_up'
    add_column :rounds, :ordered_up, :boolean, default: false
    add_column :rounds, :current_bidder_seat, :integer

    # Add index for current_bidder_seat since it will be queried frequently
    add_index :rounds, :current_bidder_seat
  end
end
