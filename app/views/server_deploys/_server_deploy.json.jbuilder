json.extract! server_deploy, :id, :server_id, :git_branch, :commit_hash, :git_user, :created_at, :updated_at
json.url server_deploy_url(server_deploy, format: :json)
