require 'thor'
require 'scalingo_backups_manager/configuration'
require 'scalingo_backups_manager/application'
require 'scalingo_backups_manager/addon'
require 'scalingo_backups_manager/restore/mongodb'
require 'scalingo_backups_manager/restore/postgres'
require 'scalingo_backups_manager/restore/mysql'

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
        backups = addon.backups
        next unless backups.size > 0
        backup = backups.first
        download_link = backup.download_link
        if download_link
          path = ("#{addon.config[:path]}" || "backups/#{addon.addon_provider[:id]}") + "/#{Time.now.strftime("%Y%m%d")}.tar.gz"
          if File.exist?(path)
            puts "Backup already download, skipping..."
          else
            system "curl #{download_link} -o #{path} --create-dirs"
          end
        else
          puts "No download link found for #{addon.addon_provider[:id]}, Skipping..."
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

  end

  private

end
