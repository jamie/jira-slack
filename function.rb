require 'rubygems'
require 'bundler/setup'
require 'pp'

require 'slack-ruby-client'
require 'jira-ruby'

def get_jira_release(matching)
  options = {
    username: ENV['JIRA_USER'],
    password: ENV['JIRA_TOKEN'],
    site: 'https://versapayclientservices.atlassian.net',
    context_path: '',
    auth_type: :basic,
    read_timeout: 120,
  }

  client = JIRA::Client.new(options)
  current_release = client
    .Project
    .find('VA')
    .versions
    .select{|v| !v.released && v.name =~ matching }
    .sort_by(&:releaseDate)
    .first
end

def set_slack_topic(channel, topic)
  Slack.configure do |config|
    config.token = ENV['SLACK_OAUTH_TOKEN']
  end

  client = Slack::Web::Client.new

  channel = client.channels_list.channels.find{ |c|
    c.name == channel
  }
  client.conversations_setTopic(
    channel: channel.id,
    topic: topic
  )
end

release = get_jira_release(/Maintenance/)
orig_topic = "This group is responsible for ARC maintenance. :stuck_out_tongue: "
topic = "Current Release: #{release.name} targeting #{release.userReleaseDate}"
set_slack_topic('bot-testing', orig_topic + topic)
