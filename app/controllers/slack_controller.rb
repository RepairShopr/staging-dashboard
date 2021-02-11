class SlackController < ActionController::Base
  include ActionView::Helpers::DateHelper

  before_action :parse_payload, only: %i[super_staging_interactivity]
  before_action :verify_super_staging, only: %i[slash_super_staging super_staging_event super_staging_interactivity]
  before_action :initialize_super_staging, only: %i[slash_super_staging super_staging_event super_staging_interactivity]
  skip_before_action :verify_authenticity_tokenr

  def staging

    # create a slash command pointing to this app /slack/staging, with a command like '/staging'
    #  https://api.slack.com/apps
    #  when you first test it out after "installing" it - just watch the payload it sends you to get the TOKEN and team domain for the authZ

    if params[:team_domain].present? && params[:token].present?
      raise "BadAuth(tail logs to find it)" unless params[:team_domain] == ENV['SLACK_TEAM_DOMAIN'] && params[:token] == ENV['SLACK_TOKEN']

      yellow = "#f89406"
      white  = "#ffffff"
      black  = "#000000"
      green  = "#62c462"

      args = params[:text].split(' ')

      case args.shift
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
        response_payload[:attachments] << {fallback: "<#{ENV['SITE_URL']}|Click to see dashboard>", text: "<#{ENV['SITE_URL']}|Click to see dashboard>", color: black}

        render json: response_payload and return

        ################################################################# RESERVE A STAGING SERVER ################################################
      when 'reserve'
        git_remote = args.shift
        hours      = args.shift
        body       = args.join(" ")

        user    = params[:user_name]
        user_id = params[:user_id]

        purpose     = "#{body} by #{user}"
        valid_hours = hours.present? && hours.include?('hr')

        server = Server.find_by_alias(git_remote.downcase)

        raise "Not found, try /staging reserve ENV_NAME(like staging3) Nhrs(like 4hrs) YOUR_COMMENT" unless (server && valid_hours)

        server.reserve!(purpose, hours, user_id)

        response_payload = {
            response_type: "in_channel",
            text:          "I reserved that for you! Yay!"
        }
        render json: response_payload and return

        ################################################################# RELEASE/UN-RESERVE A STAGING SERVER ################################################
      when 'release'
        git_remote = args.shift
        server     = Server.find_by_alias(git_remote.downcase)

        raise "Not found, try /staging release ENV_NAME(like staging3)" unless server

        server.release!

        response_payload = {
            response_type: "in_channel",
            text:          "#{server.name} has been released. It's free!"
        }
        render json: response_payload and return
      end
    end
    response_payload = {
        response_type: "ephemeral",
        text:          "I didn't catch that, example commands are:
```
list
status
reserve staging2 4hrs important testing thing
release ss1
```
"
    }
    render json: response_payload
  rescue => ex
    puts "EXCEPTION: #{ex}"
    puts ex.backtrace

    response_payload = {
        response_type: "ephemeral",
        text:          "Dang, we got a server error.. Something about #{ex}"
    }
    render json: response_payload
  end

  # TODO make bot respond to messages that mention @super_staging the same as a slash command (this should work in threads)
  def slash_super_staging
    command = params[:command]
    text    = params[:text]
    args    = text.split(' ')

    # Don't search for public/private after "reserve" command (in case part of purpose)
    head_args, tail_args = args.split(SuperStaging::SlashCommand::RESERVE)

    response_type = nil
    response_type = Slack::ResponseType::PUBLIC if head_args.delete('public')
    response_type = Slack::ResponseType::PRIVATE if head_args.delete('private')

    # Restore args with potentially modified head_args
    args = if tail_args.nil?
      # "reserve" was not in args
      head_args
    else
      # "reserve" was in args so put it back with potentially modified head_args
      head_args + [SuperStaging::SlashCommand::RESERVE] + tail_args
    end

    debug     = !!args.delete('debug')
    op        = args.shift
    show_help = op.nil?
    op        ||= 'list'

    response_type ||= SuperStaging::SlashCommand::COMMANDS.dig(op, :default_visibility) || Slack::ResponseType::PRIVATE

    blocks = []

    blocks << Slack::View.section(Slack::View.plain_text(params.to_json)) if debug

    new_blocks, response_type = @super_staging.process_slash_command!(op, args, response_type)

    blocks += new_blocks

    # TODO add button to show help
    blocks << Slack::View.section(Slack::View.markdown("For more information try `#{command} help`.")) if show_help

    response_payload = {
        response_type: response_type.to_s,
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
    render json: {error: 'Invalid token'}, status: :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(params[:token], ENV['SUPER_STAGING_VERIFY_TOKEN'])
  end

  def parse_payload
    self.params = ActionController::Parameters.new JSON.parse params[:payload]
  end

  def initialize_super_staging
    @super_staging = SuperStaging.new(params)
  end
end