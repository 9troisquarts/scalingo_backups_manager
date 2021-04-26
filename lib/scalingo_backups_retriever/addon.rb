require 'scalingo_backups_retriever/configuration'
require 'scalingo_backups_retriever/backup'

module ScalingoBackupsRetriever

  class Addon

    attr_accessor :application, :addon, :config

    DEFAULT_DATABASE_API_ROOT_URL = "https://db-api.osc-fr1.scalingo.com"

    def self.find(app, id, config: {})
      addon = Configuration.client.addons.find(app.id, id).data
      self.new(app, addon, config: config)
    end

    def initialize(app, addon, config: {})
      raise "Application must be set" unless app && app.is_a?(ScalingoBackupsRetriever::Application)
      @application = app
      @addon = addon
      @config = config
    end

    def database_api_url(options: {})
      return @database_api_url if @database_api_url
      @database_api_url = "#{options[:database_api_root_url] || DEFAULT_DATABASE_API_ROOT_URL}/api/databases/#{id}"
    end

    def client(options: {})
      return @client if @client
      scalingo = Scalingo::Client.new
      scalingo.authenticate_with(access_token: ENV["SCALINGO_API_TOKEN"])
      response = scalingo.addons.token(application.id, id).data
      if response.try(:[], :token)
        bearer_token = response[:token]
      else
        raise "An error occured during addon authentication"
      end

      addon_cli_config = Scalingo::Client.new
      addon_cli_config.token = bearer_token
      @client = Scalingo::API::Client.new(database_api_url(options), scalingo: addon_cli_config)
    end


    [:id, :resource_id, :addon_provider].each do |attr_name|
      define_method attr_name do
        addon[attr_name]
      end
    end

    def backups
      response = client.authenticated_connection.get("#{database_api_url}/backups").body
      return [] unless response[:database_backups] && response[:database_backups].size > 0
      bcks = []
      response[:database_backups].each do |backup|
        bcks.push ScalingoBackupsRetriever::Backup.new(self, backup[:id])
      end
      bcks
    end

  end

end
