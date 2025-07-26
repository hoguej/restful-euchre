class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.string :session_id, null: false, index: { unique: true }
      t.string :name

      t.timestamps
    end
  end
end
