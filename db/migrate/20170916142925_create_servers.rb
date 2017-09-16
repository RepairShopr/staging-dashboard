class CreateServers < ActiveRecord::Migration[5.1]
  def change
    create_table :servers do |t|
      t.string :name
      t.string :description
      t.string :logo_url
      t.string :status
      t.datetime :reserved_until
      t.string :reserved_for
      t.string :slack_channel

      t.timestamps
    end
  end
end
