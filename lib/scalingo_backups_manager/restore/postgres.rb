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
          skip_rm: false,
          port: nil,
        })
        destination_path = filename.split("/")
        backup_name = destination_path.pop.gsub(".tar.gz", "")
        destination_path = destination_path.join("/") + backup_name + "/"
        if Dir.exist?(destination_path)
          puts "Unzipped backup is already present, skipping..."
        else
          Dir.mkdir(destination_path) unless Dir.exist?(destination_path)
          untar_cmd = "tar zxvf #{filename} -C #{destination_path}"
          system untar_cmd
        end
        rails_db_config = YAML.load(ERB.new(File.read("config/#{opts[:database_config_file]}")).result)[opts[:env].to_s]
        config = {
          host: rails_db_config["host"],
          database: rails_db_config["database"],
          password: rails_db_config["password"],
          user: rails_db_config["user"],
          port: rails_db_config["port"]
        }
        restore_cmd = ""
        if config[:password].present?
          restore_cmd = "PGPASSWORD=#{config[:password]} "
        end
        restore_cmd << "/usr/bin/env"
        restore_cmd << " pg_restore"

        file_path = Dir["#{destination_path}*.pgsql"]
        if file_path.empty?
          puts "*** No SQL file found in tar ***"
          return
        end
        restore_cmd << " #{file_path.first}"

        if config[:host].present?
          restore_cmd << " -h #{opts[:host] || config[:host] || 'localhost'}"
        end
        if config[:user].present?
          restore_cmd << " -U #{config[:user]}"
        end

        if opts[:port].present? || config[:port].present?
          restore_cmd << " -p #{opts[:port] || config[:port] || 5432}"
        end

        restore_cmd << " -d #{config[:database]} --no-owner"

        puts "*** Restoring backup to Postgres database ***"
        puts restore_cmd
        system(restore_cmd)
        FileUtils.rm_r destination_path unless opts[:skip_rm]
      end

    end
  end
end
