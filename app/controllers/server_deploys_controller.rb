class ServerDeploysController < ApplicationController
  before_action :set_server_deploy, only: [:show, :edit, :update, :destroy]

  # GET /server_deploys
  # GET /server_deploys.json
  def index
    @server_deploys = ServerDeploy.all
  end

  # GET /server_deploys/1
  # GET /server_deploys/1.json
  def show
  end

  # GET /server_deploys/new
  def new
    @server_deploy = ServerDeploy.new
  end

  # GET /server_deploys/1/edit
  def edit
  end

  # POST /server_deploys
  # POST /server_deploys.json
  def create
    @server_deploy = ServerDeploy.new(server_deploy_params)

    respond_to do |format|
      if @server_deploy.save
        format.html { redirect_to @server_deploy, notice: 'Server deploy was successfully created.' }
        format.json { render :show, status: :created, location: @server_deploy }
      else
        format.html { render :new }
        format.json { render json: @server_deploy.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /server_deploys/1
  # PATCH/PUT /server_deploys/1.json
  def update
    respond_to do |format|
      if @server_deploy.update(server_deploy_params)
        format.html { redirect_to @server_deploy, notice: 'Server deploy was successfully updated.' }
        format.json { render :show, status: :ok, location: @server_deploy }
      else
        format.html { render :edit }
        format.json { render json: @server_deploy.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /server_deploys/1
  # DELETE /server_deploys/1.json
  def destroy
    @server_deploy.destroy
    respond_to do |format|
      format.html { redirect_to server_deploys_url, notice: 'Server deploy was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_server_deploy
      @server_deploy = ServerDeploy.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def server_deploy_params
      params.require(:server_deploy).permit(:server_id, :git_branch, :commit_hash, :git_user)
    end
end
