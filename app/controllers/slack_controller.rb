class SlackController < ActionController::Base
  include ActionView::Helpers::DateHelper

  before_action :parse_payload, only: %i[super_staging_interactivity]
  before_action :verify_super_staging, only: %i[slash_super_staging super_staging_event super_staging_interactivity]
  before_action :initialize_super_staging, only: %i[slash_super_staging super_staging_event super_staging_interactivity]

  def staging

    # create a slash command pointing to this app /slack/staging, with a command like '/staging'
    #  https://api.slack.com/apps
    #  when you first test it out after "installing" it - just watch the payload it sends you to get the TOKEN and team domain for the authZ

    if params[:team_domain].present? && params[:token].present?
      raise "BadAuth(tail logs to find it)" unless params[:team_domain] == ENV['SLACK_TEAM_DOMAIN'] && params[:token] == ENV['SLACK_TOKEN']

      yellow = "#f89406"
      white  = "#ffffff"
      green  = "#62c462"

      case params[:text].split(" ").first
        ################################################################ LIST THE SERVERS STATUS ################################################
      when 'list'

        response_payload = {
            response_type: "in_channel",
            attachments:   []
        }
        Server.order(:name).each do |server|
          if server.reserved_until.present? && server.reserved_until > Time.now - 6.hours
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
        body       = params[:text].split(' ')[3..-1].to_a.join(" ")
        hours      = params[:text].split(" ").third
        user       = params[:user_name]
        if hours.present? && hours.include?("hr")
          new_time = Time.now + (hours.to_i).hours
        else
          new_time = nil
        end

        server = Server.find_by(git_remote: git_remote)

        raise "Not found, try /staging reserve ENV_NAME(like staging3) Nhrs(like 4hrs) YOUR_COMMENT" and return unless (server && new_time)

        server.update!(reserved_until: new_time, reserved_for: "#{body} by #{user}")

        response_payload = {
            response_type: "in_channel",
            text:          "I reserved that for you! Yay!"
        }
        render json: response_payload and return

      end

    end
    response_payload = {
        response_type: "in_channel",
        text:          "I didn't catch that, example commands are:
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
        text:          "Dang, we got a server error.. Something about #{ex}"
    }
    render json: response_payload and return
  end

  def slash_super_staging
    text = params[:text]
    args = text.split(' ')

    public = args.include? 'public'

    blocks = [
        (Slack::View.section(Slack::View.plain_text(params.to_json)) if args.include? 'debug'),
        *@super_staging.servers_blocks(include_button: !public)
    ].compact

    response_payload = {
        response_type: (public ? 'in_channel' : 'ephemeral'),
        blocks:        blocks
    }

    render json: response_payload
  end

  def super_staging_event
    case params[:type]
    when 'url_verification'
      return render json: {challenge: params[:challenge]}
    when 'event_callback'
      case params.dig(:event, :type)
      when 'app_home_opened'
        @super_staging.publish_home!
      end
    end

    # Slack always wants us to acknowledge receipt
    head :ok
  end

  def super_staging_interactivity
    case params[:type]
    when 'block_actions'
      @super_staging.process_block_actions!
    when 'view_submission'
      @super_staging.process_view_submission!
    end

    # Slack always wants us to acknowledge receipt
    head :ok
  end

  private

  def verify_super_staging
    # TODO validate with signature instead https://api.slack.com/docs/verifying-requests-from-slack#a_recipe_for_security
    render json: {error: 'Invalid token'}, status: :unauthorized unless params[:token] == ENV['SUPER_STAGING_VERIFY_TOKEN']
  end

  def parse_payload
    self.params = ActionController::Parameters.new JSON.parse params[:payload]
  end

  def initialize_super_staging
    @super_staging = SuperStaging.new(params)
  end
end