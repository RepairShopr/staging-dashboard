module Slack
  module View
    extend self

    def home(blocks)
      {
          type:   'home',
          blocks: Array.wrap(blocks)
      }
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

    def button(text, action, value = nil)
      {
          type:      "button",
          text:      plain_text(text),
          action_id: action,
          value:     value
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
          payload
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