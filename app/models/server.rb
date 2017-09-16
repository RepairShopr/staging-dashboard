class Server < ApplicationRecord
  has_many :deploys, class_name: "ServerDeploy"
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
#
#------------------------------------------------------------------------------
