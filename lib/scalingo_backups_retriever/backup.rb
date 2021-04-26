module ScalingoBackupsRetriever

  class Backup
    attr_accessor :addon, :id

    def initialize(add, id)
      @addon = add
      @id = id
    end

    def download_link
      response = addon.client.authenticated_connection.get("#{addon.database_api_url}/backups/#{id}/archive").body
      return nil unless response[:download_url]
      response[:download_url]
    end

  end

end
