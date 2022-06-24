module Agents
  class GeforcenowNewGameAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_5m'

    description do
      <<-MD
      The huginn Geforcenow new game agent checks if a new game is available on the Geforcenow service.

      `debug` is used to verbose mode.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "id": 100845911,
            "title": "Shadow Warrior 3",
            "sortName": "shadow_warrior_03",
            "isFullyOptimized": false,
            "steamUrl": "https://store.steampowered.com/app/1036890",
            "store": "Steam",
            "publisher": "Devolver Digital",
            "genres": [
              "Action",
              "Adventure",
              "First-Person Shooter"
            ],
            "status": "AVAILABLE"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    def validate_options

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      check_status
    end

    private

    def check_status()
      first
      second
    end

    def first
      uri = URI.parse("https://static.nvidiagrid.net/supported-public-game-list/locales/gfnpc-en-US.json")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:97.0) Gecko/20100101 Firefox/97.0"
      request["Accept"] = "*/*"
      request["Accept-Language"] = "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3"
      request["Origin"] = "https://www.nvidia.com"
      request["Connection"] = "keep-alive"
      request["Referer"] = "https://www.nvidia.com/"
      request["Sec-Fetch-Dest"] = "empty"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Site"] = "cross-site"
      request["Te"] = "trailers"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      log "request status : #{response.code}"
      payload = JSON.parse(response.body)
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do |game|
              create_event payload: game
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload.each do |game|
              found = false
#              if interpolated['debug'] == 'true'
#                log "game"
#                log game
#              end
              last_status.each do |gamebis|
                if game['id'] == gamebis['id']
                  found = true
                end
#                if interpolated['debug'] == 'true'
#                  log "gamebis"
#                  log gamebis
#                  log "found is #{found}!"
#                end
              end
              if found == false && game['status'] == 'AVAILABLE'
#                if interpolated['debug'] == 'true'
#                  log "found is #{found}! so event created"
#                  log game
#                end
                create_event payload: game
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end

    def second
      uri = URI.parse("https://api-prod.nvidia.com/gfngames/v1/gameList")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json;charset=utf-8"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:101.0) Gecko/20100101 Firefox/101.0"
      request["Accept"] = "*/*"
      request["Accept-Language"] = "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3"
      request["Origin"] = "https://www.nvidia.com"
      request["Connection"] = "keep-alive"
      request["Referer"] = "https://www.nvidia.com/"
      request["Sec-Fetch-Dest"] = "empty"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Site"] = "same-site"
      request["Dnt"] = "1"
      request["Pragma"] = "no-cache"
      request["Cache-Control"] = "no-cache"
      request["Te"] = "trailers"
      request.body = "{ apps(country:\"FR\" language:\"fr_FR\" after:\"MTMwMA==\" ) {\n  numberReturned\n  pageInfo {\n    endCursor\n    hasNextPage\n  }\n  items {\n  title\n  sortName\nvariants{\n  appStore\n  publisherName\n  \n    }\n  }\n}}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      if interpolated['debug'] == 'true'
        log "response.body"
        log response.body
      end

      log "request status : #{response.code}"
      payload = JSON.parse(response.body)
      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status_second']
          if "#{memory['last_status_second']}" == ''
            payload['data']['apps']['items'].each do |game|
              create_event payload: game
            end
          else
            last_status = memory['last_status_second'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload['data']['apps']['items'].each do |game|
              found = false
              if interpolated['debug'] == 'true'
                log "game"
                log game
              end
              last_status['data']['apps']['items'].each do |gamebis|
                if game == gamebis
                  found = true
                end
                if interpolated['debug'] == 'true'
#                  log "gamebis"
#                  log gamebis
                  log "found is #{found}!"
                end
              end
#              if found == false && game['status'] == 'AVAILABLE'
              if found == false
                if interpolated['debug'] == 'true'
                  log "found is #{found}! so event created"
                  log game
                end
                create_event payload: game
              end
            end
          end
          memory['last_status_second'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status_second']
          memory['last_status_second'] = payload.to_s
        end
      end
    end
  end
end
