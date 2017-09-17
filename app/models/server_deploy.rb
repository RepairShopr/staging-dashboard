class ServerDeploy < ApplicationRecord
  belongs_to :server


  def self.create_from_params(server: nil, params: nil)
    puts "IN_CREATE: #{params}"
    return {save: false, params: params} unless params[:git_branch]

    deploy = server.deploys.new
    deploy.git_branch = params[:git_branch]
    deploy.git_user = params[:git_user]
    deploy.git_commit_message = params[:git_commit_message]
    deploy.commit_hash = params[:commit_hash]
    deploy.save!

    deploy
  end

end

#------------------------------------------------------------------------------
# ServerDeploy
#
# Name               SQL Type             Null    Default Primary
# ------------------ -------------------- ------- ------- -------
# id                 INTEGER              false           true   
# server_id          integer              true            false  
# git_branch         varchar              true            false  
# commit_hash        varchar              true            false  
# git_user           varchar              true            false  
# created_at         datetime             false           false  
# updated_at         datetime             false           false  
# git_commit_message text                 true            false  
#
#------------------------------------------------------------------------------
