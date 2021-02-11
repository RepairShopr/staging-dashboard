class ApiController < ActionController::Base
  protect_from_forgery :except => [:deploy_log, :heroku_deploy_log_hook]
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
  rescue => ex
    return render json: {success: false, error_message: ex, backtrace: ex.backtrace}, status: :internal_server_error
  end

  def heroku_deploy_log_hook
    build_status = params.dig("data", "status")
    return render json: { success: true, status: build_status } unless build_status == "succeeded" # only succeeded has slug info we want, skip other statuses

    environment    = params.dig("data", "app", "name")
    user_deploying = params.dig("actor", "email").split("@").first.strip
    commit         = params.dig("data", "slug", "commit")
    branch         = Github.get_branch_name_from_commit(commit)
    log_message    = params.dig("data", "slug", "commit_description") # always seems to be "" when QA deploys
    log_message    = log_message.present? ? log_message : Github.compare_changes_summary(branch || commit)

    heroku_log_params = {
      git_remote: environment, git_user: user_deploying, git_commit_message: log_message, commit_hash: commit, git_branch: branch
    }

    server = Server.find_by(git_remote: environment)
    if server.present?
      last_deploy_commit = server.deploys.last.try(:commit_hash)
      server.deploys.create_from_params(server: server, params: heroku_log_params) unless last_deploy_commit == commit # prevent dupes from normal deploys
      return render json: {success: true}
    else
      return render json: {success: false} # heroku will continue to retry for 72 hours unless we return 2XX response.
    end
  rescue => ex
    return render json: {success: false, error_message: ex, backtrace: ex.backtrace}, status: :internal_server_error
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
