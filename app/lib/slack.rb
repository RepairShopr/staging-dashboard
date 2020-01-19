module Slack
  module View
    extend self

    def home(blocks)
      {
          type:   'home',
          blocks: Array.wrap(blocks)
      }
    end

    def modal(title, blocks, callback_id: nil, submit: nil, close: nil)
      {
          type:        'modal',
          callback_id: callback_id,
          title:       wrap_plain_text(title),
          blocks:      Array.wrap(blocks),
          submit:      wrap_plain_text(submit),
          close:       wrap_plain_text(close),
      }.compact
    end

    def section(text, accessory: nil, fields: nil)
      {
          type:      'section',
          text:      text,
          accessory: accessory.presence,
          fields:    fields.presence
      }.compact
    end

    def context(elements)
      {
          type:     'context',
          elements: Array.wrap(elements)
      }
    end

    def markdown(text)
      {
          type: 'mrkdwn',
          text: text
      }
    end

    def plain_text(text, emoji: true)
      {
          type:  'plain_text',
          text:  text,
          emoji: emoji
      }
    end

    def wrap_plain_text(text)
      case text
      when String
        plain_text text
      when Hash
        text
      else
        nil
      end
    end

    def button(text, action, value = nil)
      {
          type:      "button",
          text:      plain_text(text),
          action_id: action,
          value:     value
      }.compact
    end

    def plain_text_input(label, multiline: false, block_id: nil, action_id: nil, placeholder: nil)
      {
          type:     'input',
          block_id: block_id,
          label:    wrap_plain_text(label),
          element:  {
                        type:        'plain_text_input',
                        multiline:   multiline,
                        action_id:   action_id,
                        placeholder: wrap_plain_text(placeholder)
                    }.compact
      }.compact
    end

    def date(datetime, format, fallback: datetime.to_s, link: nil)
      link_segment = ("^#{link}" if link.present?)
      "<!date^#{datetime.to_i}^#{format}#{link_segment}|#{fallback}>"
    end

    def user_link(user)
      if user.present?
        "<@#{user}>"
      else
        ':shrug:'
      end
    end

    def link(url, text)
      "<#{url.strip}|#{text.strip}>"
    end
  end

  module Api
    extend self

    def post_response(response_url, payload)
      pp response_url, payload
      pp Faraday.post(
          response_url,
          payload.to_json,
          "Content-Type" => "application/json"
      )
    end

    def views_open(trigger_id, view, private_metadata: nil)
      pp view
      pp Faraday.post(
          'https://slack.com/api/views.open',
          {
              token:            ENV['SUPER_STAGING_ACCESS_TOKEN'],
              trigger_id:       trigger_id,
              private_metadata: private_metadata,
              view:             view.to_json
          }.compact
      )
    end

    def views_publish(user_id, view)
      pp view
      pp Faraday.post(
          'https://slack.com/api/views.publish',
          token:   ENV['SUPER_STAGING_ACCESS_TOKEN'],
          user_id: user_id,
          view:    view.to_json
      )
    end
  end
end