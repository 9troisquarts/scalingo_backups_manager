require 'httparty'
module ScalingoBackupsManager

  class Notification

    def self.send_slack_notification(hook_url, message)
      HTTParty.post(
        hook_url,
        body: {
          message: message
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    def self.send_discord_notification(hook_url, message)
      payload = {
        user: 'Scalingo backups manager',
        content: message
      }.to_json
      HTTParty.post(
        hook_url,
        body: payload,
        headers: { 'Content-Type': 'application/json' }
      )
    end

  end

end