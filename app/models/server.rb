class Server < ApplicationRecord
  has_many :deploys, class_name: "ServerDeploy"


  def thumbnail_image
    options = {
        url: server_url,
        thumbnail_max_width: 400,
        viewport: "10247/768",
        fullpage: true,
        unique: Time.now.to_i / 60       # forces a unique request at most once an hour
    }
    url = Url2png.new(options).url
    puts url

    if Rails.env.production?
      return url
    else
      return nil
    end

  end

  def dynamic_status

  end
end

#------------------------------------------------------------------------------
# Server
#
# Name           SQL Type             Null    Default Primary
# -------------- -------------------- ------- ------- -------
# id             INTEGER              false           true   
# name           varchar              true            false  
# description    varchar              true            false  
# logo_url       varchar              true            false  
# status         varchar              true            false  
# reserved_until datetime             true            false  
# reserved_for   varchar              true            false  
# slack_channel  varchar              true            false  
# created_at     datetime             false           false  
# updated_at     datetime             false           false  
# server_url     varchar              true            false  
# git_remote     varchar              true            false  
#
#------------------------------------------------------------------------------
