class SuperStaging
  include ActionView::Helpers::DateHelper
  attr_reader :params, :updated_servers
  attr_accessor :user

  def initialize(params)
    @params          = safe_params(params)
    @user            = extract_user
    @updated_servers = {}
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
      params.permit(:user_id, :text)
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
      when 'reserve'
        private_metadata = response_metadata.merge(server_id: server.id).to_json
        Slack::Api.views_open(trigger_id, Slack::View.modal(
            "Reserve #{server.name}",
            [
                Slack::View.plain_text_input('Purpose', block_id: 'reserve_purpose', action_id: 'reserve_purpose', placeholder: "Why are you reserving #{server.name}?"),
                Slack::View.plain_text_input('Hours', block_id: 'reserve_hours', action_id: 'reserve_hours', placeholder: 'Just enter an integer')
            ],
            callback_id:      'do_reserve',
            private_metadata: private_metadata,
            submit:           'Reserve',
            close:            'Cancel'
        ))
      when 'release'
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
    when 'do_reserve'
      @_response_metadata = JSON.parse(params.dig(:view, :private_metadata)).with_indifferent_access
      server              = Server.find(response_metadata[:server_id])
      purpose             = params.dig(:view, :state, :values, :reserve_purpose, :reserve_purpose, :value)
      hours               = params.dig(:view, :state, :values, :reserve_hours, :reserve_hours, :value)
      server.reserve!(purpose, hours, user)

      respond_to_actions!
    end
  end

  def publish_home!
    Slack::Api.views_publish(user, Slack::View.home(servers_blocks))
  end

  def respond_to_actions!
    return unless response_metadata.present?

    case response_metadata[:type]
    when 'message'
      @user = nil unless response_metadata[:is_ephemeral]
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
      Slack::View.button 'Release', "release", server.id.to_s
    else
      Slack::View.button 'Reserve', "reserve", server.id.to_s
    end
  end

  def server_status_block(server, include_button: true)
    deploy                = server.deploys.last

    last_reservation_text = "Currently reserved for #{server.reserved_for}" if server.reserved?

    last_deploy_text      = [
        "Last deployed #{Slack::View.date(deploy.created_at, "#{time_ago_in_words deploy.created_at} ago ({date_short_pretty} {time})")} by #{deploy.git_user}",
        "#{Slack::View.link deploy.git_url, deploy.git_branch} #{deploy.git_commit_message.lines.first.truncate(100).strip}"
    ].join("\n") if deploy.present?

    reserve_button        = server_quick_action_button(server, user) if include_button

    {
        type:      "section",
        text:      {
            type: "mrkdwn",
            text: [
                      "#{server.status_emoji}#{server.platform_emoji} *#{server.name} (#{server.git_remote})*",
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
      when 'do_reserve'
        ":white_check_mark: Successfully reserved!"
      when 'release'
        ":white_check_mark: Successfully released!"
      end

      Slack::View.context(Slack::View.markdown(message)) if message.present?
    end
  end

  def debug_block
    Slack::View.section(Slack::View.plain_text(params.to_json))
  end
end