class AddJiraIframeUrlToServer < ActiveRecord::Migration[5.1]
  def change
    add_column :servers, :jira_iframe_url, :string
  end
end
