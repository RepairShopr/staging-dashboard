class ServerDeploy < ApplicationRecord
  belongs_to :server

end

#------------------------------------------------------------------------------
# ServerDeploy
#
# Name        SQL Type             Null    Default Primary
# ----------- -------------------- ------- ------- -------
# id          INTEGER              false           true   
# server_id   integer              true            false  
# git_branch  varchar              true            false  
# commit_hash varchar              true            false  
# git_user    varchar              true            false  
# created_at  datetime             false           false  
# updated_at  datetime             false           false  
#
#------------------------------------------------------------------------------
