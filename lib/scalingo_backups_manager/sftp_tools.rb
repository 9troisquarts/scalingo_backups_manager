require 'scalingo_backups_manager/notification'
require 'net/sftp'

module ScalingoBackupsManager
  class SftpTools
    attr_accessor :ftp_host

    def initialize(ftp_host)
      @ftp_host = ftp_host
    end

    def start
      if @ftp_host[:password]
        Net::SFTP.start(@ftp_host[:host], @ftp_host[:user], password: @ftp_host[:password], port: @ftp_host[:port]) do |sftp|
          yield(sftp) if block_given?
        end
      elsif @ftp_host[:private_key_path]
        Net::SFTP.start(@ftp_host[:host], @ftp_host[:user], key_data: [], keys: @ftp_host[:private_key_path], keys_only: true, port: @ftp_host[:port]) do |sftp|
          yield(sftp) if block_given?
        end
      end
    end

    def list_files(path)
      files = []
      start do |sftp|
        begin
          sftp.dir.glob("#{path}", "*.tar.gz").each do |file|
            files << file
          end
        rescue
        end
      end
      files
    end

    def remove!(path)
      start do |sftp|
        sftp.remove!(path)
      end
    end

    def mkdir!(path)
      start do |sftp|
        folder_tree = []
        path.split("/").each do |folder_name|
          next if folder_name.blank?
          folder_tree << folder_name
          begin
            sftp.mkdir!(folder_tree.join("/"))
          rescue
          end
        end
      end
    end

    def upload_file(filepath, remote_dir, options: {})
      filename = filepath.split('/').last
      start do |sftp|
        begin
          sftp.upload!(filepath, "#{remote_dir}/#{filename}")
        rescue
          if options.dig(:webhooks, :slack_webhook_url)
            ScalingoBackupsManager::Notification.send_slack_notification(options.dig(:webhooks, :slack_webhook_url), "An error has occured while uploading backup, see the logs for more information")
          end
          if options.dig(:webhooks, :discord_webhook_url)
            ScalingoBackupsManager::Notification.send_discord_notification(options.dig(:webhooks, :discord_webhook_url), "An error has occured while uploading backup, see the logs for more information")
          end
        end
      end
    end
  end

end