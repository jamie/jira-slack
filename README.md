## Configuration

To properly run, you'll need to authenticate with JIRA, Slack, and AWS, and then set a few environment variables.

Authentication:
- `JIRA_USER` is your jira login email
- `JIRA_TOKEN` is from [https://id.atlassian.com/manage/api-tokens]() (and used instead of your password)
- `SLACK_OAUTH_TOKEN` is defined in the app integration, which lives [https://api.slack.com/apps/A0153AYMUR3/app-home](here)

Deployment:
- `LAMBDA_FUNCTION` is the name of the function in lambda you want to publish to

## Deploying to Lambda

Local setup: `brew install awscli`, and then run `aws configure`. You'll need an AWS Access Key and Secret Key, from an [IAM account](https://console.aws.amazon.com/iam/home). Be sure they have sufficient Lambda priveleges.

Initial setup: Create a new lambda function. The name of this function should be exported as `LAMBDA_FUNCTION` locally to run deploys. Add environment variables for the other 3 variables above.

`rake publish` to build + deploy code.

From AWS console, fire a test event, it should execute.

Finally, to get the script to auto-fire, we'll need to set up CloudWatch to schedule execution on a regular basis. See [documentation here](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/Create-CloudWatch-Events-Scheduled-Rule.html).
