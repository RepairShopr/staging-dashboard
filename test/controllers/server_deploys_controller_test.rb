require 'test_helper'

class ServerDeploysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_deploy = server_deploys(:one)
  end

  test "should get index" do
    get server_deploys_url
    assert_response :success
  end

  test "should get new" do
    get new_server_deploy_url
    assert_response :success
  end

  test "should create server_deploy" do
    assert_difference('ServerDeploy.count') do
      post server_deploys_url, params: { server_deploy: { commit_hash: @server_deploy.commit_hash, git_branch: @server_deploy.git_branch, git_user: @server_deploy.git_user, server_id: @server_deploy.server_id } }
    end

    assert_redirected_to server_deploy_url(ServerDeploy.last)
  end

  test "should show server_deploy" do
    get server_deploy_url(@server_deploy)
    assert_response :success
  end

  test "should get edit" do
    get edit_server_deploy_url(@server_deploy)
    assert_response :success
  end

  test "should update server_deploy" do
    patch server_deploy_url(@server_deploy), params: { server_deploy: { commit_hash: @server_deploy.commit_hash, git_branch: @server_deploy.git_branch, git_user: @server_deploy.git_user, server_id: @server_deploy.server_id } }
    assert_redirected_to server_deploy_url(@server_deploy)
  end

  test "should destroy server_deploy" do
    assert_difference('ServerDeploy.count', -1) do
      delete server_deploy_url(@server_deploy)
    end

    assert_redirected_to server_deploys_url
  end
end
