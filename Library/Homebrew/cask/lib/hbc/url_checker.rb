require "hbc/checkable"
require "hbc/fetcher"

module Hbc
  class UrlChecker
    attr_accessor :cask, :response_status, :headers

    include Checkable

    def initialize(cask, fetcher = Fetcher)
      @cask = cask
      @fetcher = fetcher
      @headers = {}
    end

    def summary_header
      "url check result for #{cask}"
    end

    def run
      _get_data_from_request
      return if errors?
      _check_response_status
    end

    HTTP_RESPONSES = [
      "HTTP/1.0 200 OK",
      "HTTP/1.1 200 OK",
      "HTTP/1.1 302 Found",
    ].freeze

    OK_RESPONSES = {
      "http"  => HTTP_RESPONSES,
      "https" => HTTP_RESPONSES,
      "ftp"   => ["OK"],
    }.freeze

    def _check_response_status
      ok = OK_RESPONSES[cask.url.scheme]
      return if ok.include?(@response_status)
      add_error "unexpected http response, expecting #{ok.map(&:to_s).join(" or ")}, got #{@response_status}"
    end

    def _get_data_from_request
      response = @fetcher.head(cask.url)

      if response.empty?
        add_error "timeout while requesting #{cask.url}"
        return
      end

      response_lines = response.split("\n").map(&:chomp)

      case cask.url.scheme
      when "http", "https" then
        @response_status = response_lines.grep(/^HTTP/).last
        if @response_status.respond_to?(:strip)
          @response_status.strip!
          unless response_lines.index(@response_status).nil?
            http_headers = response_lines[(response_lines.index(@response_status) + 1)..-1]
            http_headers.each do |line|
              header_name, header_value = line.split(": ")
              @headers[header_name] = header_value
            end
          end
        end
      when "ftp" then
        @response_status = "OK"
        response_lines.each do |line|
          header_name, header_value = line.split(": ")
          @headers[header_name] = header_value
        end
      else
        add_error "unknown scheme for #{cask.url}"
      end
    end
  end
end
