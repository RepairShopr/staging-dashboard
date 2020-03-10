class SuperStaging
  include ActionView::Helpers::DateHelper
  attr_reader :params, :user, :updated_servers, :slash_command

  module Action
    DO_RESERVE = 'do_reserve'
    RESERVE    = 'reserve'
    RELEASE    = 'release'
  end

  module SlashCommand
    HELP    = 'help'
    LIST    = 'list'
    STATUS  = 'status'
    RELEASE = 'release'
    RESERVE = 'reserve'

    HOURS_REGEX = /\A(?<hours>\d*)h(?:ou)?rs?\z/i

    COMMANDS = {
        HELP    => {
            default_visibility: Slack::ResponseType::PRIVATE,
            usage:              "#{HELP} [<command>]",
            description:        ->(super_staging) { "Display help info. See `#{super_staging.slash_command} #{HELP} <command>` to read about specific subcommand." }
        },
        LIST    => {
            default_visibility: Slack::ResponseType::PRIVATE,
            usage:              LIST,
            description:        "List status of all staging servers. Includes \"Reserve\" buttons. If visibility is private, \"Release\" button will be displayed for servers that are currently reserved by you."
        },
        STATUS  => {
            default_visibility: Slack::ResponseType::PUBLIC,
            usage:              "#{STATUS} <server>",
            description:        "Show the status of a specific server. Does not include \"Reserve\" or \"Release\" button. You can use either the `git_alias` or `abbreviation` to specify the server."
        },
        RELEASE => {
            default_visibility: Slack::ResponseType::PRIVATE,
            usage:              "#{RELEASE} <server>",
            description:        "Release a server. You can use either the `git_alias` or `abbreviation` to specify the server."
        },
        RESERVE => {
            default_visibility: Slack::ResponseType::PRIVATE,
            usage:              "#{RESERVE} <server> <N>[hr|hrs|hour|hours] <purpose>",
            description:        "Reserve a server. You can use either the `git_alias` or `abbreviation` to specify the server. Specify the duration of the reservation in hours.\nExample: ```#{RESERVE} ss1 2hrs Test a thing.```"
        }
    }.with_indifferent_access.freeze
  end

  def initialize(params)
    @params          = safe_params(params)
    @_user           = @user = extract_user
    @updated_servers = {}
    @slash_command   = @params[:command]
  end

  def safe_params(params)
    case params[:type]
    when 'url_verification'
      params.permit(:type, :challenge)
    when 'event_callback'
      params.permit(:type, event: [:type, :user])
    when 'block_actions'
      # response_url is for block actions from messages
      # view.type is for block actions from the home view
      params.permit(:type, :response_url, :trigger_id, container: [:type, :is_ephemeral], view: [:type], actions: [:action_id, :value], user: [:id])
    when 'view_submission'
      params.permit(:type,
                    view: [:callback_id,
                           :private_metadata, # JSON-encoded string with "type", "server", and optionally "response_url", "is_ephemeral"
                           state: {
                               values: {
                                   # block_id => action_id => "value" => value
                                   reserve_purpose: {reserve_purpose: [:value]},
                                   reserve_hours:   {reserve_hours: [:value]}
                               }}],
                    user: [:id])
    else # Slash command doesn't have 'type'
      params.permit(:user_id, :text, :command)
    end
  end

  def extract_user
    case params[:type]
    when 'event_callback'
      params.dig(:event, :user)
    when 'block_actions', 'view_submission'
      params.dig(:user, :id)
    else # Slash command doesn't have 'type'
      params[:user_id]
    end
  end

  def process_block_actions!
    trigger_id = params[:trigger_id]
    actions    = params[:actions].map do |action|
      action.to_h.to_options.slice(:action_id, :value)
    end

    actions.each do |action_id:, value:|
      server = Server.find value

      case action_id
      when Action::RESERVE
        private_metadata = response_metadata.merge(server_id: server.id).to_json
        # TODO make inputs optional
        Slack::Api.views_open(trigger_id, Slack::View.modal(
            "Reserve #{server.name}",
            [
                Slack::View.plain_text_input('Purpose', block_id: 'reserve_purpose', action_id: 'reserve_purpose', placeholder: "Why are you reserving #{server.name}?"),
                Slack::View.plain_text_input('Hours', block_id: 'reserve_hours', action_id: 'reserve_hours', placeholder: 'Just enter an integer')
            ],
            callback_id:      Action::DO_RESERVE,
            private_metadata: private_metadata,
            submit:           'Reserve',
            close:            'Cancel'
        ))
      when Action::RELEASE
        server.release!

        updated_servers[value] = action_id
      else
        raise "Unknown action: #{action_id}"
      end
    end

    respond_to_actions! if updated_servers.present?
  end

  def process_view_submission!
    case params.dig(:view, :callback_id)
    when Action::DO_RESERVE
      @_response_metadata = JSON.parse(params.dig(:view, :private_metadata)).with_indifferent_access
      server              = Server.find(response_metadata[:server_id])
      purpose             = params.dig(:view, :state, :values, :reserve_purpose, :reserve_purpose, :value)
      hours               = params.dig(:view, :state, :values, :reserve_hours, :reserve_hours, :value)
      # TODO validate "hours"
      server.reserve!(purpose, hours, user)
      updated_servers[server.id.to_s] = Action::DO_RESERVE

      respond_to_actions!
    end
  end

  def with_server!(cmd, args, response_type)
    blocks = []

    server_alias = args.shift

    if server_alias.present?
      server = Server.find_by_alias(server_alias.downcase)
      if server.present?
        blocks += yield(server)
      else
        response_type = Slack::ResponseType::PRIVATE
        blocks << Slack::View.section(Slack::View.markdown(":x: *Error:* Unable to find server: '#{server_alias}'."))
      end
    else
      response_type = Slack::ResponseType::PRIVATE
      blocks << Slack::View.section(Slack::View.markdown(":x: *Error:* `#{cmd}` command requires server name."))
      blocks += help_blocks(cmd)
    end

    [blocks, response_type]
  end

  def process_slash_command!(cmd, args, response_type)
    blocks = []

    case cmd
    when SlashCommand::HELP
      help_cmd = args.shift
      blocks   += help_blocks(help_cmd)

    when SlashCommand::STATUS
      status_blocks, response_type = with_server!(cmd, args, response_type) do |server|
        self.public = response_type.public?
        server_blocks(server, include_button: false)
      end

      blocks += status_blocks

    when SlashCommand::RELEASE
      release_blocks, response_type = with_server!(cmd, args, response_type) do |server|
        server.release!
        updated_servers[server.id.to_s] = Action::RELEASE
        self.public                     = response_type.public?
        server_blocks(server, include_button: false)
      end

      blocks += release_blocks

    when SlashCommand::LIST
      self.public = response_type.public?
      blocks      += servers_blocks

    when SlashCommand::RESERVE
      use_default_hours = false

      reserve_blocks, response_type = with_server!(cmd, args, response_type) do |server|
        hours       = nil # Default duration
        hours_index = args.find_index do |arg|
          SlashCommand::HOURS_REGEX.match?(arg)
        end
        if hours_index.present?
          arg_length = 0

          # There must be a match because this was found by checking `match?`
          hour_part = SlashCommand::HOURS_REGEX.match(args[hours_index])[:hours]
          if hour_part.present?
            arg_length = 1
            hours      = hour_part.to_i
          elsif hours_index > 0
            # This arg was just "hours" without the number so check the previous arg
            hours_index -= 1
            hour_part   = args[hours_index]

            if /\A\d+\z/.match?(hour_part)
              arg_length = 2
              hours      = hour_part.to_i
            end
          end

          arg_length.times { args.delete_at(hours_index) }
        end

        purpose = args.join(' ')

        use_default_hours = hours.nil?
        hours             = 1 if use_default_hours

        server.reserve!(purpose, hours, user)

        updated_servers[server.id.to_s] = Action::DO_RESERVE
        self.public                     = response_type.public?
        server_blocks(server, include_button: false)
      end

      blocks += reserve_blocks

      blocks << Slack::View.context(Slack::View.markdown(":warning: Unable to parse hours to used default of 1 hour duration.")) if use_default_hours

    else
      # If the first arg feels like a server alias, run the "status" command on it
      return process_slash_command!('status', [cmd, *args], response_type) if cmd.present? && Server.by_alias(cmd.downcase).exists?
    end

    [blocks, response_type]
  end

  def publish_home!
    Slack::Api.views_publish(user, Slack::View.home(servers_blocks))
  end

  def respond_to_actions!
    return unless response_metadata.present?

    case response_metadata[:type]
    when 'message'
      self.public = !response_metadata[:is_ephemeral]
      Slack::Api.post_response(response_metadata[:response_url], {
          replace_original: 'true',
          blocks:           servers_blocks
      })
    when 'home'
      publish_home!
    else
      # do nothing
    end
  end

  def public=(value)
    if value
      @user = nil
    else
      @user = @_user
    end
  end

  def response_metadata
    @_response_metadata ||= if params.key?(:response_url)
      {
          type:         'message',
          is_ephemeral: params.dig(:container, :is_ephemeral),
          response_url: params[:response_url]
      }
    elsif params.dig(:view, :type) == 'home'
      {type: 'home'}
    end
  end

  def default_visibility_block(help_cmd)
    default_visibility = SlashCommand::COMMANDS.dig(help_cmd, :default_visibility)
    Slack::View.context(Slack::View.markdown("Default visibility: #{default_visibility.name}")) if default_visibility
  end

  def usage(help_cmd)
    "#{slash_command} [public|private] #{SlashCommand::COMMANDS.dig(help_cmd, :usage)}"
  end

  def usage_block(help_cmd)
    Slack::View.section(Slack::View.markdown("*Usage:* `#{usage(help_cmd)}`"))
  end

  def description_block(help_cmd)
    description = SlashCommand::COMMANDS.dig(help_cmd, :description)
    description = description.call(self) if description.respond_to?(:call)
    Slack::View.section(Slack::View.markdown(description))
  end

  def available_commands_block
    Slack::View.section(Slack::View.markdown(<<MRKDWN))
Available commands:
```
#{SlashCommand::COMMANDS.keys.map { |cmd| usage(cmd) }.join("\n")}
```
MRKDWN
  end

  def visibility_explanation_block
    Slack::View.section(Slack::View.markdown("You can add a visibility modifier to any command to change the response type. \"public\" means the response will be visible to everyone in the channel. \"private\" means the response will only be visible to you. For most commands, the visibility modifier can be anywhere in the command, but for \"reserve\", it must be before the \"reserve\" keyword."))
  end

  def help_blocks(help_cmd)
    blocks = []

    case help_cmd
    when 'help', 'list', 'status', 'release'
      blocks << usage_block(help_cmd)
      blocks << description_block(help_cmd)
      blocks << available_commands_block if help_cmd == 'help'

    else
      blocks << available_commands_block
    end

    blocks << visibility_explanation_block
    blocks << default_visibility_block(help_cmd)

    blocks.compact
  end

  def servers_blocks(servers = Server.order(:name), include_button: true)
    servers.map do |server|
      server_blocks(server, include_button: include_button)
    end.reduce(:+)
  end

  def server_blocks(server, include_button: true)
    [
        server_status_block(server, include_button: include_button),
        server_reserved_block(server),
        server_action_result_block(server)
    ].compact
  end

  def server_quick_action_button(server, user = nil)
    if server.reserved? && server.reserved_by == user && user.present?
      Slack::View.button "Release #{server.abbreviation}".strip, Action::RELEASE, server.id.to_s
    else
      Slack::View.button "Reserve #{server.abbreviation}".strip, Action::RESERVE, server.id.to_s
    end
  end

  def server_status_block(server, include_button: true)
    deploy                = server.deploys.last

    last_reservation_text = "Currently reserved for #{server.reserved_for}" if server.reserved?

    last_deploy_text      = [
        "Last deployed #{Slack::View.date(deploy.created_at, "#{time_ago_in_words deploy.created_at} ago ({date_short_pretty} {time})")} by #{deploy.git_user}",
        "#{Slack::View.link deploy.git_url, deploy.git_branch} #{deploy.git_commit_message.lines.first.to_s.truncate(100).strip}"
    ].join("\n") if deploy.present?

    reserve_button        = server_quick_action_button(server, user) if include_button

    {
        type:      "section",
        text:      {
            type: "mrkdwn",
            text: [
                      "#{server.status_emoji}#{server.platform_emoji} *#{server.name} (#{server.git_remote}/#{server.abbreviation})*",
                      last_reservation_text,
                      last_deploy_text
                  ].compact.join("\n")
        },
        accessory: reserve_button
    }.compact # Remove {accessory: nil} if reserve_button is not included
  end

  def server_reserved_block(server)
    if server.reserved?
      Slack::View.context(Slack::View.markdown("Reserved by #{Slack::View.user_link server.reserved_by} until #{Slack::View.date(server.reserved_until, '{date_short_pretty} {time}')}"))
    elsif server.recently_reserved?
      Slack::View.context(Slack::View.markdown("Recently released from #{Slack::View.user_link server.reserved_by} #{Slack::View.date(server.reserved_until, "#{time_ago_in_words server.reserved_until} ago {date_short_pretty} {time}")}"))
    end
  end

  def server_action_result_block(server)
    if updated_servers.key? server.id.to_s
      message = case updated_servers[server.id.to_s]
      when Action::DO_RESERVE
        ":white_check_mark: Successfully reserved!"
      when Action::RELEASE
        ":white_check_mark: Successfully released!"
      end

      Slack::View.context(Slack::View.markdown(message)) if message.present?
    end
  end

  def debug_block
    Slack::View.section(Slack::View.plain_text(params.to_json))
  end
end