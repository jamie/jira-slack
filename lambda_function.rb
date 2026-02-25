require "rubygems"
require "bundler/setup"

require "active_support/all"
require "slack-ruby-client"
require "jira-ruby"

JIRA_CLIENT = JIRA::Client.new(
  username: ENV["JIRA_USER"],
  password: ENV["JIRA_TOKEN"],
  site: "https://versapayclientservices.atlassian.net",
  context_path: "",
  auth_type: :basic,
  read_timeout: 120
)

Slack.configure do |config|
  config.token = ENV["SLACK_OAUTH_TOKEN"]
end

class JiraRelease
  def initialize(client)
    @client = client
    @releases = nil
  end

  def maintenance_topic
    prefix = "C-AR Maintenance schedule (hover me)"
    summary = maintenance_releases.map { |release|
      deploy_date = Date.parse(release.releaseDate)
      verify_date = deploy_date - 2
      freeze_date = deploy_date - 6

      ":ship:#{date_fmt(deploy_date)} :gh-green:#{date_fmt(verify_date)} :ice_cube:#{date_fmt(freeze_date)} &gt;#{release_short_name(release)}"
    }
    [prefix, summary].flatten.join("\n")
  end

  def car_release_topic
    summary = car_releases.map { |release|
      deploy_date = Date.parse(release.releaseDate)
      verify_date = deploy_date - 2
      freeze_date = deploy_date - 6

      # verify_freeze = ":gh-green:#{date_fmt(verify_date)} :ice_cube:#{date_fmt(freeze_date)} " if release == car_releases.first
      ":ship:#{date_fmt(deploy_date)} - #{release.name}"
    }
    # Using jamie's bitly.com account
    "<https://bit.ly/vpy-calendar|Next release>: " + [summary].flatten.join("\n")
  end

  def maintenance_releases
    releases.select { |v| v.name =~ /Maintenance/i }.take(3)
  end

  def car_releases
    releases.select { |v| Date.parse(v.releaseDate) >= Date.today }.take(5)
  end

  private

  def releases
    @releases ||= fetch_releases
  end

  def fetch_releases
    @client
      .Project
      .find("CAR")
      .versions
      .select { |v| !v.released && !v.archived && v.respond_to?(:releaseDate) }
      .sort_by(&:releaseDate)
  end

  def date_fmt(date)
    date.strftime("%b%-d")
  end

  def release_short_name(release)
    release
      .name
      .gsub(/C-?AR /, "")
      .gsub("Maintenance", "Maint")
      .gsub("maintenance", "maint")
      .gsub("Release", "Rel")
      .gsub(/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[^-]+/, "\\1")
      .to_s[0...20]
  end
end

class SlackChannel
  def initialize(client: nil, dry_run: false)
    @client = client || Slack::Web::Client.new
    @dry_run = dry_run
  end

  def set_topic(channel_name, topic)
    topic = normalize_topic(topic)

    if @dry_run
      puts "~~~ ##{channel_name}"
      puts topic
      return
    end

    channel = find_channel(channel_name)
    return if channel.topic.value == topic

    @client.conversations_setTopic(
      channel: channel.id,
      topic: topic
    )
  end

  private

  def normalize_topic(topic)
    # Note: Slack normalizes the topic name on post:
    # - converts unicode characters to their :emoji: equivalent
    # - encodes html entities like &gt; instead of >
    # - If over 250 chars, truncates to around 240 and adds `...`
    # So to avoid channel spam, our topic needs to be pre-normalized for an equality check.
    topic.size > 250 ? topic[...240] + "..." : topic
  end

  def find_channel(channel_name)
    cursor = nil
    loop do
      pager = @client.conversations_list(cursor:, limit: 200)
      needle = pager.channels.find { |c| c.name == channel_name }
      return needle if needle

      cursor = pager.response_metadata.next_cursor
    end
  end
end

def lambda_handler(*, dry: false, **)
  jira = JiraRelease.new(JIRA_CLIENT)
  slack = SlackChannel.new(dry_run: dry)
  slack.set_topic("maintenanceteam", jira.maintenance_topic)
  # slack.set_topic("car-releases", jira.car_release_topic)
end
