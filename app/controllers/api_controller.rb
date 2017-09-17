class ApiController < ActionController::Base
  protect_from_forgery :except => [:deploy_log]
  before_action :set_default_response_format


  def deploy_log
    server = Server.find_by id: params[:server_id]
    server ||= Server.find_by git_remote: params[:git_remote]
  end




  def set_default_response_format
    request.format = :json
  end
end
