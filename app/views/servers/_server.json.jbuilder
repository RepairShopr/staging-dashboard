json.extract! server, :id, :name, :description, :logo_url, :status, :reserved_until, :reserved_for, :slack_channel, :created_at, :updated_at
json.url server_url(server, format: :json)
