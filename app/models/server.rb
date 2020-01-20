class Server < ApplicationRecord
  has_many :deploys, class_name: "ServerDeploy"

  def self.find_by_alias(aliaz)
    where(name: aliaz).or(where(git_remote: aliaz)).or(where(abbreviation: aliaz)).first
  end

  def thumbnail_image
    return nil #this is breaking?
    if !Rails.env.production?
      return nil
    end

    options = {
        url:                 server_url,
        thumbnail_max_width: 400,
        viewport:            "10247/768",
        fullpage:            true,
        unique:              Time.now.to_i / 60 # forces a unique request at most once an hour
    }
    url     = Url2png.new(options).url
    puts url

    return url
  end

  def dynamic_status

  end

  def live_url
    server_url
  end

  def reserved?
    reserved_until.present? && reserved_until > Time.now
  end

  def recently_reserved?
    reserved_until.present? && (6.hours.ago..Time.now).include?(reserved_until)
  end

  def free?
    reserved_until.blank? || reserved_until < 6.hours.ago
  end

  def status_emoji
    if reserved?
      ':x:'
    elsif recently_reserved?
      ':warning:'
    else
      ''
    end
  end

  def platform_emoji
    case platform&.downcase
    when 'rs', 'repairshopr'
      ':rs:'
    when 'syncro'
      ':syncro:'
    when 'kabuto'
      ':kabuto:'
    else
      ''
    end
  end

  def kabuto?
    platform.downcase == 'kabuto'
  end

  def repairshopr?
    platform.downcase.in? %w[rs repairshopr]
  end

  alias_method :rs?, :repairshopr?

  def syncro?
    platform.downcase == 'syncro'
  end

  def rsyn?
    repairshopr? || syncro?
  end

  def reserve!(purpose, hours, user)
    update!(reserved_for: purpose, reserved_until: (hours.to_i.nonzero? || 1).hours.from_now, reserved_by: user)
  end

  def release!
    update!(reserved_until: nil)
  end
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
