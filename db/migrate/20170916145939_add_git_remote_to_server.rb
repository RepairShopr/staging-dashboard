class AddGitRemoteToServer < ActiveRecord::Migration[5.1]
  def change
    add_column :servers, :git_remote, :string
  end
end
