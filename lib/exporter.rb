# frozen_string_literal: true

require "http"
require "down"
require "down/http"
require "parallel"

class Exporter
  def export
    page = 1
    generation_ids = Set.new

    puts "Fetching generation ids in collection..."

    loop do
      response = HTTP
        .auth("Bearer #{ENV["API_KEY"]}")
        .headers(accept: "application/json", content_type: "application/json")
        .get(
          "https://labs.openai.com/api/labs/collections/#{ENV["COLLECTION_ID"]}/generations",
          params: {
            page: 1,
            limit: 50
          }
        )

      unless response.status.success?
        raise "ERROR: Failed to grab generation ids in collection!"
      end

      json = JSON.parse(response)

      generation_ids += json["data"].map { |h| h["id"] }

      if page >= json["total_pages"]
        break
      end

      page += 1
    end

    puts "Done fetching generation ids in collection."

    generation_ids_to_download = generation_ids.reject { |generation_id|
      File.exist?(File.join(ENV["FOLDER"], "#{generation_id}.png"))
    }

    unless generation_ids_to_download.size > 0
      puts "Folder #{ENV["FOLDER"]} is up to date with collection."
      return
    end

    down = Down::Http.new { |client| client.auth("Bearer #{ENV["API_KEY"]}") }

    Parallel.each(
      generation_ids_to_download,
      in_threads: 10,
      progress: "Downloading generations..."
    ) do |generation_id|
      retry_count = 0
      begin
        down.download(
          "https://labs.openai.com/api/labs/generations/#{generation_id}/download",
          destination: File.join(ENV["FOLDER"], "#{generation_id}.png")
        )
      rescue => e
        if retry_count == 10
          raise "ERROR: Failed to download generation over #{retry_count} times, aborting."
        end

        sleep 3**retry_count
        retry_count += 1

        puts "WARN: #{e.message}"

        retry
      end
    end
  end
end
