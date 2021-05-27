require 'yaml'
require 'erb'
module ScalingoBackupsManager
  module Restore
    class Postgres

      def self.restore(filename, options = {})
        opts = options.reverse_merge({
          database_config_file: 'database.yml',
          env: 'development',
          host: nil,
          remote_database_name: nil,
          local_database_name: nil,
          skip_rm: false
        })
        destination_path = filename.split("/")
        backup_name = destination_path.pop.gsub(".tar.gz", "")
        destination_path = destination_path.join("/") + backup_name + "/"
        p destination_path
        if Dir.exist?(destination_path)
          puts "Unzipped backup is already present, skipping..."
        else
          Dir.mkdir(destination_path) unless Dir.exist?(destination_path)
          untar_cmd = "tar zxvf #{filename} -C #{destination_path}"
          system untar_cmd
        end

        rails_db_config = YAML.load(ERB.new(File.read("config/#{opts[:database_config_file]}")).result)[opts[:env]]
        config = {
          host: rails_db_config["hosts"].first,
          database: rails_db_config["database"],
          password: rails_db_config["options"]["password"],
          user: rails_db_config["options"]["user"],
        }

        restore_cmd = "/usr/bin/env psql #{config[:database]} -h #{opts[:host] || config[:host]}"

        if config[:user].present?
          restore_cmd << " --u #{config[:user]}"
          if config[:password].present?
            restore_cmd << " --password"
            restore_cmd << " #{config[:password]}"
          end
        end

        if config[:port].present?
          restore_cmd << " -p #{config[:port] || 5432}"
        end

        restore_cmd << " < #{destination_path}"

        puts "*** Restoring backup to Postgres database ***"
        system(restore_cmd)
        FileUtils.rm_r destination_path unless opts[:skip_rm]
      end

    end
  end
end
