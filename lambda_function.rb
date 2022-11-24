require 'rubygems'
require 'bundler/setup'
require 'pp'

require 'slack-ruby-client'
require 'jira-ruby'

JIRA_CONFIG = {
  username: ENV['JIRA_USER'],
  password: ENV['JIRA_TOKEN'],
  site: 'https://versapayclientservices.atlassian.net',
  context_path: '',
  auth_type: :basic,
  read_timeout: 120
}.freeze

Slack.configure do |config|
  config.token = ENV['SLACK_OAUTH_TOKEN']
end

def get_jira_releases(matching, count)
  JIRA::Client
    .new(JIRA_CONFIG)
    .Project
    .find('VA')
    .versions
    .select { |v| !v.released && v.name =~ matching && v.respond_to?(:releaseDate) }
    .sort_by(&:releaseDate)
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
  "C-AR Maintenance schedule (hover me)\n" +
  releases.map { |release|
    deploy_date = Date.parse(release.releaseDate)
    verify_date = deploy_date - 2
    ":construction: #{release.name} - verify by EOD #{verify_date.strftime("%b. %-d")}, deploy #{deploy_date.strftime("%b. %-d")}"
  }.join("\n")
end

def lambda_handler(*)
  releases = get_jira_releases(/^Maintenance/, 3)
  set_slack_topic('maintenanceteam', topic_from(releases))
end
