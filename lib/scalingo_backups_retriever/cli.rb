require 'thor'
require 'scalingo_backups_retriever/configuration'
require 'scalingo_backups_retriever/application'
require 'scalingo_backups_retriever/addon'

module ScalingoBackupsRetriever
  class Cli < Thor
    desc "install", "It will guide you in the configuration process"
    def install
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
      applications = ScalingoBackupsRetriever::Application.all
      if applications.empty?
        puts "You do not have access to any scalingo application"
        return
      end
      application = nil
      while application.nil?
        applications.each_with_index do |application, index|
          puts "#{index + 1} - #{application[:name]}"
        end
        application_choice = ask("Select an application :").to_i
        application = ScalingoBackupsRetriever::Application.find(applications[application_choice - 1][:id]) if application_choice > 0 && applications[application_choice - 1]
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
        addon = ScalingoBackupsRetriever::Addon.find(application, addons[addon_choice - 1][:id]) if addon_choice > 0 && addons[addon_choice - 1]
      end
      configuration.add_addon_to_app(application, addon)
    end

    desc "download", "Download last backup all of application in configuration"
    def download
      configuration = Configuration.new
      unless configuration
        puts "No configuration found, execute set_configuration"
        return
      end

      configuration.addons.each do |addon|
        backups = addon.backups
        next unless backups.size > 0
        backup = backups.first
        download_link = backup.download_link
        if download_link
          path = ("#{addon.config[:path]}" || "backups/#{addon.addon_provider[:id]}") + "/#{backup.id}"
          system "curl #{download_link} -o #{path} --create-dirs"
        else
          puts "No download link found for #{addon.addon_provider[:id]}, Skipping..."
        end
      end
    end

  end
end
