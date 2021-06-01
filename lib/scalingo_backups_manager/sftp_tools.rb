require 'net/sftp'

module ScalingoBackupsManager
  class SftpTools
    attr_accessor :ftp_host

    def initialize(ftp_host)
      @ftp_host = ftp_host
    end

    def start
      Net::SFTP.start(@ftp_host[:host], @ftp_host[:user], password: @ftp_host[:password], port: @ftp_host[:port]) do |sftp|
        yield(sftp) if block_given?
      end
    end

    def list_files(path)
      files = []
      start do |sftp|
        sftp.dir.glob("#{path}", "*.tar.gz").each do |file|
          files << file
        end
      end
      files
    end

    def remove!(path)
      start do |sftp|
        sftp.remove!(path)
      end
    end

    def mkdir!(path)
      start do |sftp|
        folder_tree = []
        path.split("/").each do |folder_name|
          next if folder_name.blank?

          folder_tree << folder_name
          begin
            sftp.mkdir!(folder_tree.join("/"))
          rescue
          end
        end
      end
    end

    def upload_file(filepath, remote_dir)
      filename = filepath.split('/').last
      start do |sftp|
        sftp.upload!(filepath, "#{remote_dir}/#{filename}")
      end
    end
  end

end