require 'rubygems'
require 'bundler/setup'
require 'pp'

require 'slack-ruby-client'
require 'jira-ruby'

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

SLACK_CHANNEL='bot-testing'
# set_slack_topic(SLACK_CHANNEL, "Testing From Script")
