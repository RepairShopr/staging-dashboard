class AddAbbreviationToServers < ActiveRecord::Migration[5.1]
  def change
    add_column :servers, :abbreviation, :string
  end
end
