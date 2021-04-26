require 'scalingo_backups_retriever/configuration'

module ScalingoBackupsRetriever
  class Application

    class << self
      def client
        Configuration.client
      end

      def all
        client.apps.all&.data || []
      end

      def find(id)
        app = client.apps.find(id)&.data
        self.new(app)
      end

    end

    attr_accessor :application

    def initialize(app)
      @application = app
    end

    [:id, :name].each do |attr_name|
      define_method attr_name do
        application[attr_name]
      end
    end

    def client
      Configuration.client
    end

    def addons
      Configuration.client.addons.for(application[:id])&.data || []
    end

  end
end
