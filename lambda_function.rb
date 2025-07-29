require "rubygems"
require "bundler/setup"

require "active_support/all"
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

def jira_releases
  JIRA::Client
    .new(JIRA_CONFIG)
    .Project
    .find("CAR")
    .versions
    .select { |v| !v.released && !v.archived && v.respond_to?(:releaseDate) }
    .sort_by(&:releaseDate)
end

def set_slack_topic(channel, topic, dry: false)
  # Note: Slack normalizes the topic name on post:
  # - converts unicode characters to their :emoji: equivalent
  # - encodes html entities like &gt; instead of >
  # - If over 250 chars, truncates to around 240 and adds `...`
  # So to avoid channel spam, our topic needs to be pre-normalized for an equality check.
  topic = topic[...240] + "..." if topic.size > 250

  if dry
    puts "~~~ ##{channel}"
    puts topic
    return
  end

  client = Slack::Web::Client.new

  cursor = nil
  channel = loop do
    pager = client.conversations_list(cursor:, limit: 200)
    needle = pager.channels.find { |c| c.name == channel }
    break needle if needle

    cursor = pager.response_metadata.next_cursor
  end
  return if channel.topic.value == topic

  client.conversations_setTopic(
    channel: channel.id,
    topic: topic
  )
end

def maintenance_topic_from(releases)
  prefix = "C-AR Maintenance schedule (hover me)"
  summary = releases.map { |release|
    deploy_date = Date.parse(release.releaseDate)
    verify_date = deploy_date - 2
    freeze_date = deploy_date - 6

    ":ship:#{date_fmt(deploy_date)} :gh-green:#{date_fmt(verify_date)} :ice_cube:#{date_fmt(freeze_date)} &gt;#{release_short_name(release)}"
  }
  [prefix, summary].flatten.join("\n")
end

def car_release_topic_from(releases)
  summary = releases.map { |release|
    deploy_date = Date.parse(release.releaseDate)
    verify_date = deploy_date - 2
    freeze_date = deploy_date - 6

    # verify_freeze = ":gh-green:#{date_fmt(verify_date)} :ice_cube:#{date_fmt(freeze_date)} " if release == releases.first
    ":ship:#{date_fmt(deploy_date)} - #{release.name}"
  }
  # Using jamie's bitly.com account
  "<https://bit.ly/vpy-calendar|Next release>: " + [summary].flatten.join("\n")
end

def date_fmt(date)
  date.strftime("%b%-d")
end

def release_short_name(release)
  release
    .name
    .gsub(/C-?AR /, "")
    .gsub("Maintenance", "Maint")
    .gsub("Release", "Rel")
    .gsub(/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[^-]+/, "\\1")
    .to_s[0...20]
end

def lambda_handler(*, dry: false, **)
  maintenance = jira_releases.select { |v| v.name =~ /Maintenance/ }.take(3)
  set_slack_topic("maintenanceteam", maintenance_topic_from(maintenance), dry: dry)

  # car_releases = jira_releases.select { |v| Date.parse(v.releaseDate) >= Date.today }.take(5)
  # set_slack_topic("car-releases", car_release_topic_from(car_releases), dry: dry)
end
