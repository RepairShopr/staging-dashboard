class AddServerUrlToServers < ActiveRecord::Migration[5.1]
  def change
    add_column :servers, :server_url, :string
  end
end
