class ApplicationController < ActionController::Base
  # http_basic_authenticate_with name: "dashboard", password: "password", except: :index
  protect_from_forgery with: :exception
end
