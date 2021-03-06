require 'net/https'

class Whitehall::Uploader::AttachmentCache
  class RetrievalError < RuntimeError; end

  class << self
    attr_accessor :default_root_directory
  end

  def initialize(root_dir = self.class.default_root_directory, logger = Logger.new($stdout))
    @root_dir = root_dir
    @logger = logger
  end

  def fetch(url)
    Entry.new(@root_dir, @logger, url).fetch
  end

  class FileTypeDetector
    def self.detected_type(local_path)
      file_type = `file "#{local_path}"`.strip
      if file_type =~ /PDF document/
        :pdf
      elsif file_type =~ /Microsoft Excel/
        :xls
      elsif file_type =~ /Microsoft Office Word/
        :doc
      else
        nil
      end
    end
  end

  private

  class Entry
    attr_accessor :root_dir, :logger, :original_url

    def initialize(root_dir, logger, original_url)
      @root_dir = root_dir
      @logger = logger
      @original_url = original_url
    end

    def fetch
      if cached_file
        File.open(cached_file, 'r')
      else
        download(original_url)
      end
    end

    def cache_path
      File.join(@root_dir, Digest::MD5.hexdigest(original_url))
    end

    def cached_file
      Dir[cache_path + "/*"][0]
    end

    def download(url)
      response = do_request(url)
      if response.is_a?(Net::HTTPOK)
        local_path = store(url, response)
        File.open(local_path, 'r')
      elsif response.is_a?(Net::HTTPMovedPermanently) || response.is_a?(Net::HTTPMovedTemporarily)
        download(response['Location'])
      else
        raise RetrievalError, "got response status #{response.code}"
      end
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET => e
      raise RetrievalError, "due to #{e.class}: '#{e.message}'"
    rescue URI::InvalidURIError => e
      raise RetrievalError, "due to invalid URL - #{e.class}: '#{e.message}'"
    end

    def do_request(url)
      uri = URI.parse(url)
      raise RetrievalError, "url not understood to be HTTP" unless uri.is_a?(URI::HTTP)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.is_a?(URI::HTTPS))
      http.request_get(uri.path)
    end

    def filename(url, response)
      filename_from_content_disposition_header(response) || filename_from_url(url)
    end

    def filename_from_content_disposition_header(response)
      if response['Content-Disposition']
        parts = response['Content-Disposition'].split(/; */)
        parts.each do |part|
          if match = part.match(/filename *= *"(.*)"/)
            return match[1]
          end
        end
      end
      nil
    end

    def filename_from_url(url)
      File.basename(URI.parse(url).path)
    end

    def store(url, response)
      FileUtils.mkdir_p(cache_path)
      local_path = File.join(cache_path, filename(url, response))
      @logger.info "Fetching #{url} to #{local_path}"
      File.open(local_path, 'w', encoding: 'ASCII-8BIT') do |file|
        file.write(response.body)
      end
      ensure_file_has_extension(local_path)
    end

    def ensure_file_has_extension(local_path)
      if File.extname(local_path).blank?
        detected_type = FileTypeDetector.detected_type(local_path)
        if detected_type
          FileUtils.mv(local_path, local_path + ".#{detected_type}")
          local_path = local_path + ".#{detected_type}"
          @logger.info "Detected file type: #{detected_type}; moved to #{local_path}"
        else
          @logger.warn "Unknown file type for #{local_path}"
        end
      end
      local_path
    end
  end
end


