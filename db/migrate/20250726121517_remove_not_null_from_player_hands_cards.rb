class RemoveNotNullFromPlayerHandsCards < ActiveRecord::Migration[8.0]
  def change
    change_column_null :player_hands, :cards, true
  end
end
