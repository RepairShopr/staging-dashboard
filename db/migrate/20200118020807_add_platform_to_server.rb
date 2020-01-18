class AddPlatformToServer < ActiveRecord::Migration[5.1]
  def change
    add_column :servers, :platform, :string
    add_column :servers, :reserved_by, :string
  end
end
