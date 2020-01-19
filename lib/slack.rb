module Slack
  module View
    def home(blocks)
      {
          type: 'home',
          blocks: blocks
      }
    end

    def section(text, accessory: nil, fields: nil)
      {
          type: 'section',
          text: text,
          **({accessory: accessory} if accessory.present?),
          **({fields: fields} if fields.present?)
      }
    end

    def context(elements)
      {
          type: 'context',
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
          type: 'plain_text',
          text: text,
          emoji: emoji
      }
    end

    def button(text, action)
      {
          type:  "button",
          text:  plain_text(text),
          value: action
      }
    end

    def date(datetime, format, fallback: datetime.to_s, link: nil)
      link_segment = ("^#{link}" if link.present?)
      "<!date^#{datetime.to_i}^#{format}#{link_segment}|#{fallback}>"
    end
  end

  module Api
    def views_publish(user_id, view)
      Faraday.post(
          'https://slack.com/api/views.publish',
          token: ENV['SUPER_STAGING_ACCESS_TOKEN'],
          user_id: user_id,
          view: view
      )
    end
  end
end