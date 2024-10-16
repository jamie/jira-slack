require "rubygems"
require "bundler/setup"

require "slack-ruby-client"
require "jira-ruby"

JIRA_CONFIG = {
  username: ENV["JIRA_USER"],
  password: ENV["JIRA_TOKEN"],
  site: "https://versapayclientservices.atlassian.net",
  context_path: "",
  auth_type: :basic,
  read_timeout: 120
}.freeze

Slack.configure do |config|
  config.token = ENV["SLACK_OAUTH_TOKEN"]
end

def get_jira_releases(matching, count)
  JIRA::Client
    .new(JIRA_CONFIG)
    .Project
    .find("CAR")
    .versions
    .select { |v| !v.released && !v.archived && v.name =~ matching && v.respond_to?(:releaseDate) }
    .sort_by(&:releaseDate)
    .tap{ pp _1 }
    .take(count)
end

def set_slack_topic(channel, topic)
  client = Slack::Web::Client.new

  channel = client
    .conversations_list
    .channels
    .find { |c| c.name == channel }
  return if channel.topic.value == topic

  client.conversations_setTopic(
    channel: channel.id,
    topic: topic
  )
end

def topic_from(releases)
  # Note: Slack normalizes the topic name on post:
  # - converts unicode characters to their :emoji: equivalent
  # - encodes html entities like &gt; instead of >
  # - If over 250 chars, truncates to around 240 and adds `...`
  # So to avoid channel spam, our topic needs to be pre-normalized for an equality check.

  prefix = "C-AR Maintenance schedule (hover me)"
  summary = releases.map { |release|
    deploy_date = Date.parse(release.releaseDate)
    verify_date = deploy_date - 2
    freeze_date = deploy_date - 6
    release_name = release
      .name
      .gsub(/C-?AR /, "")
      .gsub("Maintenance", "Maint")
      .gsub("Release", "Rel")
      .gsub(/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[^-]+/, "\\1")
      .to_s[0...20]

    ":ship:#{date_fmt(deploy_date)} :gh-green:#{date_fmt(verify_date)} :ice_cube:#{date_fmt(freeze_date)} &gt;#{release_name}"
  }
  [prefix, summary].flatten.join("\n")
end

def date_fmt(date)
  date.strftime("%b%-d")
end

def lambda_handler(*, dry: false, **)
  releases = get_jira_releases(/Maintenance/, 3)
  if dry
    pp releases.map(&:name)
    puts topic_from(releases)
  else
    set_slack_topic("maintenanceteam", topic_from(releases))
  end
end
