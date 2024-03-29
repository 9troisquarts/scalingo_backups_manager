require 'thor'
require 'scalingo_backups_manager/configuration'
require 'scalingo_backups_manager/application'
require 'scalingo_backups_manager/addon'
require 'scalingo_backups_manager/restore/mongodb'
require 'scalingo_backups_manager/restore/postgres'
require 'scalingo_backups_manager/restore/mysql'
require 'scalingo_backups_manager/sftp_tools'

module ScalingoBackupsManager

  DATABASE_PROVIDER_IDS = %w(mongodb postgresql mysql)
  class Cli < Thor
    desc "install", "It will guide you in the configuration process"
    method_options all: :boolean
    def install
      all = options[:all]
      unless Configuration.file_exists?
        puts "Configuration file not found"
        puts "Creating file..."
        Configuration.create_file
      end
      unless ENV["SCALINGO_API_TOKEN"]
        puts "The environment variable SCALINGO_API_TOKEN is not set, Exiting..."
        return
      end
      configuration = Configuration.new
      applications = ScalingoBackupsManager::Application.all
      if applications.empty?
        puts "You do not have access to any scalingo application"
        return
      end
      if all
        puts "Fetching scalingo app"
        applications.each do |app|
          application = ScalingoBackupsManager::Application.find(app[:id])
          application.addons.each do |addon|
            addon = ScalingoBackupsManager::Addon.find(application, addon[:id])
            configuration.add_addon_to_app(application, addon) if addon.addon_provider[:id] && DATABASE_PROVIDER_IDS.include?(addon.addon_provider[:id])
          end
        end
      else
        application = nil
        while application.nil?
          applications.each_with_index do |application, index|
            puts "#{index + 1} - #{application[:name]}"
          end
          application_choice = ask("Select an application :").to_i
          application = ScalingoBackupsManager::Application.find(applications[application_choice - 1][:id]) if application_choice > 0 && applications[application_choice - 1]
        end

        addons = application.addons
        if addons.empty?
          puts "This application have no addons"
          return
        end
        addon = nil
        while addon.nil?
          p "#### Selecting #{application.name} addon ####"
          addons.each_with_index do |addon, index|
            puts "#{index + 1} - #{addon[:addon_provider][:name]} #{addon[:plan][:display_name]}"
          end
          addon_choice = ask("Select addon :").to_i
          addon = ScalingoBackupsManager::Addon.find(application, addons[addon_choice - 1][:id]) if addon_choice > 0 && addons[addon_choice - 1]
        end
        configuration.add_addon_to_app(application, addon)
      end
    end

    desc "download", "Download last backup all of application in configuration"
    method_options application: :string, addon: :string
    def download
      searched_application = options[:application]
      searched_addon = options[:addon]
      configuration = Configuration.new
      unless configuration
        puts "No configuration found, invoking install"
        invoke :install
      end

      configuration.for_each_addons(searched_application, searched_addon) do |application, addon|
        begin
          puts "Downloading #{application.name} last backup"
          backups = addon.backups
          next unless backups.size > 0
          backup = backups.first
          download_link = backup.download_link
          if download_link
            path = ("#{addon.config[:path]}" || "backups/#{addon.addon_provider[:id]}") + "/#{Time.now.strftime("%Y%m%d")}.tar.gz"
            if File.exist?(path)
              puts "Backup already download, skipping..."
            else
              system "curl #{download_link} -o #{path} --create-dirs -k"
            end
          else
            puts "No download link found for #{addon.addon_provider[:id]}, Skipping..."
          end
        rescue
          puts "Issue with configuration of #{application.name}"
        end
      end
    end

    desc "restore", "Restore application backup to database"
    method_option :application, type: :string, aliases: "-A", desc: "Application of addons to restore"
    method_option :addon, :type => :string, aliases: "-a", desc: "Addon to restore"
    method_option :port, type: :string, aliases: "-p", desc: "Port of database"
    method_option :host, type: :string, aliases: "-h", desc: "Host of your database server, useful when you are running your database in docker"
    method_option :remote_database, type: :string, aliases: "-rdb", desc: "Name of remote database to restore"
    method_option :database, type: :string, aliases: "-db", desc: "Name of local database, default is the database set in your database.yml/mongoid.yml"
    method_option :skip_backup_delete, type: :boolean, aliases: "-skip-rm", desc: "Skip the deletion of folder after restore is complete"
    def restore
      invoke :download, [], application: options[:application], addon: options[:addon]
      configuration = Configuration.new
      configuration.for_each_addons(options[:application], options[:addon]) do |application, addon|
        path = ("#{addon.config[:path]}" || "backups/#{addon.addon_provider[:id]}") + "/#{Time.now.strftime("%Y%m%d")}.tar.gz"
        opts = { port: options[:port], host: options[:host], remote_database_name: options[:remote_database], local_database_name: options[:database], skip_rm: options[:skip_backup_delete] }
        case addon.addon_provider[:id]
        when 'mongodb'
          ScalingoBackupsManager::Restore::Mongodb.restore(path, opts)
        when 'postgresql'
          ScalingoBackupsManager::Restore::Postgres.restore(path, opts)
        when 'mysql'
          ScalingoBackupsManager::Restore::Mysql.restore(path, opts)
        else
          puts "Restore of #{addon.addon_provider[:id]} is not handle yet"
        end
      end
    end

    desc "upload_to_ftp", "Upload last backup to FTP"
    def upload_to_ftp
      invoke :download, [], application: options[:application], addon: options[:addon]
      configuration = Configuration.new
      opts = {
        webhooks: configuration.config[:webhooks]
      }
      configuration.for_each_addons do |application, addon|
        step = 1
        sftp_config = addon.sftp_config
        path = ("#{addon.config[:path]}" || "backups/#{addon.addon_provider[:id]}") + "/#{Time.now.strftime("%Y%m%d")}.tar.gz"
        next unless File.exists?(path)
        puts "** Upload backup for #{application.name} **"

        sftp = ScalingoBackupsManager::SftpTools.new(sftp_config[:auth])

        folders = [
          sftp_config.dig(:auth, :dir),
          sftp_config.dig(:dir) || application.name,
          addon.addon_provider[:id]
        ]

        if sftp_config[:retention].blank?
          remote_path = "/" + [folders].delete_if(&:blank?).join("/")
          sftp.mkdir!(remote_path)
          sftp.upload_file(path, remote_path, options: opts)
          next
        end

        sftp_config[:retention].each do |k, retention_config|
          retention_folders = folders.dup
          retention_folders << sftp_config.dig(:retention, k, :dir)
          remote_path = "/" + retention_folders.delete_if(&:blank?).join("/")
          puts "#{step} - Creating remote directory at #{remote_path}"
          step += 1
          sftp.mkdir!(remote_path)
          case k
          when "daily"
            sftp.upload_file(path, remote_path, options: opts)
            files = sftp.list_files(remote_path)
            p files.length
            puts "#{step} - Checking daily backups"
            step += 1
            if files.size > retention_config[:ttl]
              files_to_remove = files.sort_by(&:name).shift(files.size - retention_config[:ttl])
              puts "#{step} - Removing #{files_to_remove.size} backups because of ttl configuration"
              files_to_remove.each do |file|
                puts "Removing file #{remote_path + "/" + file.name}"
                sftp.remove!(remote_path + "/" + file.name)
              end
            end
          when "monthly"
            next unless Date.today.day == 1
            sftp.upload_file(path, remote_path, options: opts)
            puts "#{step} - Checking monthly backups"
            step += 1
          end
        end

      end
      FileUtils.rm_r 'backups/'
    end

  end

  private

end
