module Github
  class << self
    API_KEY = ENV['GITHUB_API_KEY']
    BASE_URL = "https://api.github.com"
    HEADERS = {'Content-Type' => 'application/json',
              'Authorization' => "token #{API_KEY}",
              'Accept' => "application/vnd.github.v3+json"}

    def make_request(path, method, body = {})
      conn = Faraday.new(
        url: "#{BASE_URL}/#{path}",
        headers: HEADERS
      )
      response = conn.send(method) do |req|
        req.body = body.to_json
      end

      JSON.load(response.body)
    end

    def get_path(path, body = {})
      make_request(path, :get, body)
    end

    def compare_changes(commit_or_branch)
      get_path("repos/RepairShopr/RepairShopr/compare/master...#{commit_or_branch}")
    end

    def compare_changes_summary(commit_or_branch)
      changes = compare_changes(commit_or_branch)
      commits = changes.dig('commits')
      summary = ""

      commits.each do |commit|
        name = commit.dig('commit', 'author', 'name')
        message = commit.dig('commit', 'message').strip
        summary << "#{name}: #{message}\n"
      end
      return summary
    end

    def get_commit(commit)
      get_path("repos/RepairShopr/RepairShopr/commits/#{commit}")
    end

    def get_branches(page=1)
      get_path("repos/RepairShopr/RepairShopr/branches?per_page=100&page=#{page}")
    end

    def get_branch(branch_name)
      get_path("repos/RepairShopr/RepairShopr/branches/#{branch_name}")
    end

    def get_branch_name_from_commit(commit)
      page = 1
      loop do
        branches = get_branches(page)
        break if branches.count == 0
        branches.each do |branch|
          branch_commit = branch.dig("commit", "sha")
          branch_name = branch.dig("name")
          return branch_name if branch_commit == commit
        end
        page += 1
      end

      return nil
    end
  end
end