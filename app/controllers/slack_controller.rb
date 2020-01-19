class SlackController < ActionController::Base
  include ActionView::Helpers::DateHelper

  # TODO verify token
  #before_action :verify_super_staging, only: %i[super_staging super_staging_event]

  def staging

    # create a slash command pointing to this app /slack/staging, with a command like '/staging'
    #  https://api.slack.com/apps
    #  when you first test it out after "installing" it - just watch the payload it sends you to get the TOKEN and team domain for the authZ

    if params[:team_domain].present? && params[:token].present?
      raise "BadAuth(tail logs to find it)" unless params[:team_domain] == ENV['SLACK_TEAM_DOMAIN'] && params[:token] == ENV['SLACK_TOKEN']

      yellow = "#f89406"
      white = "#ffffff"
      green = "#62c462"

      case params[:text].split(" ").first
        ################################################################ LIST THE SERVERS STATUS ################################################
        when 'list'

          response_payload = {
              response_type: "in_channel",
              attachments: []
          }
          Server.order(:name).each do |server|
            if server.reserved_until.present? && server.reserved_until > Time.now-6.hours
              reserved_message = "RESERVED until #{I18n.l server.reserved_until, format: :short} for #{server.reserved_for}"
            else
              reserved_message = nil
            end

            message = "<https://#{server.server_url}|#{server.name}> #{reserved_message} last deployed #{time_ago_in_words(server.deploys.last.try(:created_at) || server.updated_at)} ago (#{server.deploys.last.try(:git_branch)}/#{server.deploys.last.try(:git_commit_message).to_s.truncate(25)}) by #{server.deploys.last.try(:git_user)}"
            response_payload[:attachments] << {fallback: message, text: message, color: reserved_message ? yellow : green}
          end
          response_payload[:attachments] << {fallback: "<#{ENV['SITE_URL']}|Click to see dashboard>", text: "<#{ENV['SITE_URL']}|Click to see dashboard>", color: "#000000"}

          render json: response_payload and return


        ################################################################# RESERVE A STAGING SERVER ################################################
        when 'reserve'
          git_remote = params[:text].split(" ").second
          body = params[:text].split(' ')[3..-1].to_a.join(" ")
          hours = params[:text].split(" ").third
          user = params[:user_name]
          if hours.present? && hours.include?("hr")
            new_time = Time.now+(hours.to_i).hours
          else
            new_time = nil
          end

          server = Server.find_by(git_remote: git_remote)

          raise "Not found, try /staging reserve ENV_NAME(like staging3) Nhrs(like 4hrs) YOUR_COMMENT" and return unless (server && new_time)

          server.update!(reserved_until: new_time, reserved_for: "#{body} by #{user}")

          response_payload = {
              response_type: "in_channel",
              text: "I reserved that for you! Yay!"
          }
          render json: response_payload and return

      end

    end
    response_payload = {
        response_type: "in_channel",
        text: "I didn't catch that, example commands are:
```list
status
reserve staging2 4hrs important testing thing
```
"
    }
    render json: response_payload and return
  rescue => ex
    puts "EXCEPTION: #{ex}"
    puts ex.backtrace

    response_payload = {
        response_type: "in_channel",
        text: "Dang, we got a server error.. Something about #{ex}"
    }
    render json: response_payload and return
  end

  def super_staging
    if params[:text].split(' ').first == 'home'
      blocks = Slack::View.section(Slack::View.plain_text(params.to_json))
      Slack::Api.views_publish('U34AGSLG5', Slack::View.home(blocks))
    end

    blocks = []

    if params[:text].split(' ').include? 'debug'
      blocks << Slack::View.section(Slack::View.plain_text(params.to_json))
    end

    blocks += server_sections(params[:user_id])

    response_payload = {
        response_type: 'ephemeral',
        blocks:        blocks
    }

    render json: response_payload
  end

  def super_staging_event
    case params[:type]
    when 'url_verification'
      render json: {challenge: params[:challenge]}
    when 'event_callback'
      event = params[:event]
      case event[:type]
      when 'app_home_opened'
        Slack::Api.views_publish(event[:user], Slack::View.home(server_sections(event[:user])))
      else
        head :not_implemented
      end

      head :ok
    else
      head :ok
    end
  end

  private

  def server_sections(user)
    servers = Server.order(:name)

    sections = []
    servers.each do |server|
      deploy         = server.deploys.last
      reserve_button = if server.reserved? && server.reserved_by == user
        Slack::View.button 'Release', "release_#{server.id}"
      else
        Slack::View.button 'Reserve', "reserve_#{server.id}"
      end
      last_deploy = if deploy.present?
        [
            "Last deployed #{Slack::View.date(deploy.created_at, "#{time_ago_in_words deploy.created_at} ({date_short_pretty} {time})")} by #{deploy.git_user}",
            "#{deploy.slack_git_link} #{deploy.git_commit_message.truncate(100)}"
        ].join("\n")
      end
      sections << {
          type:      "section",
          text:      {
              type: "mrkdwn",
              text: ["#{server.status_emoji}#{server.platform_emoji} *#{server.name} (#{server.git_remote})*", last_deploy].compact.join("\n")
          },
          accessory: reserve_button
      }
      if server.reserved?
        sections << Slack::View.context(Slack::View.markdown("Reserved by #{server.reserved_by} until #{Slack::View.date(server.reserved_until, '{date_short_pretty} {time}')}"))
      end
    end
  end

  def verify_super_staging
    render json: {error: 'Invalid token'}, status: :unauthorized unless params[:token] == ENV['SUPER_STAGING_VERIFY_TOKEN']
  end
end