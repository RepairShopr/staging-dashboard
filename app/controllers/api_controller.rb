class ApiController < ActionController::Base
  protect_from_forgery :except => [:deploy_log]
  before_action :set_default_response_format


  def deploy_log
    # f = Faraday.post "http://staging-dashboard.lvh.me:3000/api/deploy_log", log: {git_remote: "staging3", git_user: "troy", git_branch: "one-db", git_commit_message: "this is a big feature", commit_hash: "abc123asdf"}
    server = Server.find_by id: params[:log][:server_id]
    server ||= Server.find_by git_remote: params[:log][:git_remote]
    if server
      server.deploys.create_from_params(server: server, params: log_params)
      puts "IN SERVER"
      return render json: {success: true}
    end
    return render json: {success: false}, status: :unprocessable_entity
  end




  private

  def log_params
    params.require(:log).permit(:server_id, :name, :description,
                                :logo_url, :status, :reserved_until,
                                :reserved_for, :slack_channel,
                                :server_url, :git_remote, :git_branch,
                                :commit_hash, :git_commit_message, :git_user)
  end

  def set_default_response_format
    request.format = :json
  end
end
