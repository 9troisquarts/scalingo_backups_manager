require 'scalingo'
require 'yaml'
require 'scalingo_backups_manager/application'
require 'scalingo_backups_manager/addon'

module ScalingoBackupsManager

  class Configuration
    attr_accessor :config
    FILE_NAME = "scalingo-backups-config.yml"

    def self.file_exists?
      File.exist?(FILE_NAME)
    end

    def self.create_file
      File.open(FILE_NAME, 'w+') do |f|
        f.flock(File::LOCK_EX)
        content = f.read
        f.rewind
        f.write({ region: 'osc-fr-1', apps: []}.to_yaml)
        f.flush
      end
    end

    def self.client
      return @client if @client
      @client = Scalingo::Client.new
      @client.authenticate_with(access_token: ENV["SCALINGO_API_TOKEN"])
      @client
    end

    def self.write_config(config)
      File.open(FILE_NAME, "w+") do |f|
        f.flock(File::LOCK_EX)
        f.truncate(0)
        f.write(config.to_yaml)
        f.flush
      end
    end

    def initialize
      @file = File.open(FILE_NAME)
      unless @file
        puts "Configuration file does not exist"
        return
      end
      @config = YAML.load(@file.read) || { apps: [] }
    end

    def add_addon_to_app(application, addon)
      @config.deep_merge!({ apps: { "#{application.name}": { id: application.id, addons: { "#{addon.addon_provider[:id]}": { id: addon.id, path: "backups/#{application.name}/#{addon.addon_provider[:id]}/" } } } } })
      self.class.write_config(@config)
    end

    def for_each_addons(application_uid, addon_uid)
      @config[:apps].each do |application_name, application_config|
        next if application_uid && application_uid != application_name.to_s
        next unless application_config[:id]
        application = ScalingoBackupsManager::Application.find(application_config[:id])
        next unless application_config[:addons] && application_config[:addons].size > 0
        application_config[:addons].each do |addon_name, addon_config|
          next if addon_uid && addon_uid != addon_name.to_s
          next unless addon_config[:id]
          addon = ScalingoBackupsManager::Addon.find(application, addon_config[:id], config: addon_config)
          yield(application, addon) if block_given?
        end
      end
    end


  end

end
