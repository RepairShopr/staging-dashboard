class AddGitCommitMessageToServerDeploys < ActiveRecord::Migration[5.1]
  def change
    add_column :server_deploys, :git_commit_message, :text
  end
end
