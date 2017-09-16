class CreateServerDeploys < ActiveRecord::Migration[5.1]
  def change
    create_table :server_deploys do |t|
      t.integer :server_id
      t.string :git_branch
      t.string :commit_hash
      t.string :git_user

      t.timestamps
    end
  end
end
