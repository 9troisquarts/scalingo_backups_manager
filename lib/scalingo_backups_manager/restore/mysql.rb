require 'yaml'
require 'fileutils'
require 'erb'
module ScalingoBackupsManager
  module Restore
    class Mysql

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
          unless Dir.exist?(destination_path)
            p "Creating destination folder..."
            Dir.mkdir(destination_path)
          end
          untar_cmd = "tar zxvf #{filename} -C #{destination_path}"
          p "Untar file with command #{untar_cmd}"
          system untar_cmd
        end

        database_yml_content = File.read("config/#{opts[:database_config_file]}")
        parsed_database_config = ERB.new(database_yml_content).result
        rails_db_config = YAML.load(parsed_database_config)[opts[:env]]
        config = {
          host: rails_db_config["host"],
          database: rails_db_config["database"],
          password: rails_db_config["password"],
          user: rails_db_config["username"],
          port: rails_db_config["port"]
        }

        restore_cmd = "/usr/bin/env mysql -h #{opts[:host] || config[:host]}"

        if config[:user].present?
          restore_cmd << " -u #{config[:user]}"
          if config[:password].present?
            restore_cmd << " --password="
            restore_cmd << "#{config[:password]}"
          end
        end

        if config[:port].present? || opts[:port].present?
          restore_cmd << " -P #{opts[:port] || config[:port] || 5432}"
        end

        restore_cmd << " #{config[:database]}"

        file_path = Dir["#{destination_path}*.sql"]
        if file_path.empty?
          puts "*** No SQL file found in tar ***"
          return
        end
        restore_cmd << " < #{file_path.first}"

        puts "*** Restoring backup to mysql database ***"
        puts "Command: #{restore_cmd}"
        system(restore_cmd)
        FileUtils.rm_r destination_path unless opts[:skip_rm]
      end

    end
  end
end
