require 'yaml'
require 'erb'
module ScalingoBackupsManager
  module Restore
    class Mongodb

      def self.restore(filename, options = {})
        opts = options.reverse_merge({
          database_config_file: 'mongoid.yml',
          env: 'development',
          host: nil,
          remote_database_name: nil,
          local_database_name: nil,
          skip_rm: false
        })
        destination_path = filename.split("/")
        backup_name = destination_path.pop.gsub(".tar.gz", "")
        destination_path = destination_path.join("/")
        if Dir.exist?(destination_path)
          puts "Unzipped backup is already present, skipping..."
        else
          untar_cmd = "tar zxvf #{filename} -C #{destination_path}"
          system untar_cmd
        end

        rails_db_config = YAML.load(ERB.new(File.read("config/#{opts[:database_config_file]}")).result)[opts[:env]]["clients"]["default"]
        config = {
          host: rails_db_config["hosts"].first,
          database: rails_db_config["database"],
          password: rails_db_config["options"]["password"],
          user: rails_db_config["options"]["user"],
          auth_source: rails_db_config["options"]["auth_source"]
        }

        restore_cmd = "/usr/bin/env mongorestore --drop -h #{opts[:host] || config[:host]}"
        if opts[:local_database_name].present?
          restore_cmd << " --db #{opts[:local_database_name]}"
        end

        if opts[:remote_database_name].present?
          restore_cmd << " --dir \"#{destination_path}#{backup_name}/#{opts[:remote_database_name]}\""
        else
          restore_cmd << " --dir \"#{destination_path}#{backup_name}/\""
        end

        if config[:auth_source].present?
          restore_cmd << " --authenticationDatabase #{config[:auth_source]}"
        end
        if config[:user].present?
          restore_cmd << " -u #{config[:user]}"
          if config[:password].present?
            restore_cmd << " --password"
            restore_cmd << " #{config[:password]}"
          end
        end

        puts "*** Restoring backup to Mongodb database ***"
        system(restore_cmd)
        FileUtils.rm_r destination_path unless opts[:skip_rm]
      end

    end
  end
end
