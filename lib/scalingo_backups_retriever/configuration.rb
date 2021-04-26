require 'scalingo'
require 'yaml'
require 'scalingo_backups_retriever/application'
require 'scalingo_backups_retriever/addon'

module ScalingoBackupsRetriever

  class Configuration
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

    def addons
      adds = []
      @config[:apps].each do |application_name, application_config|
        next unless application_config[:id]
        application = ScalingoBackupsRetriever::Application.find(application_config[:id])
        next unless application_config[:addons] && application_config[:addons].size > 0
        application_config[:addons].each do |addon_name, addon_config|
          next unless addon_config[:id]
          adds.push ScalingoBackupsRetriever::Addon.find(application, addon_config[:id], config: addon_config)
        end
      end
      adds
    end


  end

end
