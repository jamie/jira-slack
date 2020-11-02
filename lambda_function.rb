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

def get_jira_release(matching)
  JIRA::Client
    .new(JIRA_CONFIG)
    .Project
    .find('VA')
    .versions
    .select { |v| !v.released && v.name =~ matching }
    .min_by(&:releaseDate)
end

def set_slack_topic(channel, topic)
  client = Slack::Web::Client.new

  channel = client
            .channels_list
            .channels
            .find { |c| c.name == channel }
  return if channel.topic.value == topic

  client.conversations_setTopic(
    channel: channel.id,
    topic: topic
  )
end

def lambda_handler(*)
  release = get_jira_release(/^Maintenance/)
  orig_topic = 'This group is responsible for ARC maintenance. :stuck_out_tongue:  '
  topic = "#{release.name} due #{release.releaseDate}"
  set_slack_topic('maintenanceteam', orig_topic + topic)
end
