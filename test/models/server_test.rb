require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

#------------------------------------------------------------------------------
# Server
#
# Name            SQL Type             Null    Default Primary
# --------------- -------------------- ------- ------- -------
# id              INTEGER              false           true   
# name            varchar              true            false  
# description     varchar              true            false  
# logo_url        varchar              true            false  
# status          varchar              true            false  
# reserved_until  datetime             true            false  
# reserved_for    varchar              true            false  
# slack_channel   varchar              true            false  
# created_at      datetime             false           false  
# updated_at      datetime             false           false  
# server_url      varchar              true            false  
# git_remote      varchar              true            false  
# jira_iframe_url varchar              true            false  
# platform        varchar              true            false  
# reserved_by     varchar              true            false  
# abbreviation    varchar              true            false  
#
#------------------------------------------------------------------------------
