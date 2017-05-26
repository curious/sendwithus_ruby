require "base64"
require_relative "error"

module SendWithUs
  class ApiNilEmailId < Error; end

  class Api
    attr_reader :configuration

    # ------------------------------ Class Methods ------------------------------

    def self.configuration
      @configuration ||= SendWithUs::Config.new
    end

    def self.configure
      yield self.configuration if block_given?
    end

    # ------------------------------ Instance Methods ------------------------------

    def initialize(options = {})
      settings = SendWithUs::Api.configuration.settings.merge(options)
      @configuration = SendWithUs::Config.new(settings)
    end

    # DEPRECATED: Please use 'send_email' instead.
    #
    # Sends the specified email with any arguments.
    #
    # * *Args*    :
    #   - +email_id+ -> ID of the email to send
    #   - +to+ -> Hash of recipient details
    #   - +data+ -> Hash of email data
    #   - +from+ -> Hash of sender details
    #   - +cc+ -> Array of CC recipients
    #   - +bcc+ -> Array of BCC recipients
    #   - +files+ -> Array of attachments
    #   - +esp_account+ -> The ESP account to use
    #   - +version_name+ -> The specific email version to use
    #   - +headers+ -> Hash of headers
    #   - +tags+ -> Array of tags
    # * *Notes*    :
    #   - "send" is already a ruby-defined method on all classes
    #
    def send_with(email_id, to, data = {}, from = {}, cc = [], bcc = [], files = [], esp_account = '', version_name = '', headers = {}, tags = [])
      warn "[DEPRECATED] 'send_with' is deprecated.  Please use 'send_email' instead."

      send_email(
        email_id,
        to,
        data: data,
        from: from,
        cc: cc,
        bcc: bcc,
        files: files,
        esp_account: esp_account,
        version_name: version_name,
        headers: headers,
        tags: tags
      )
    end

    # Sends the specified email with any optional arguments
    #
    # * *Args*    :
    #   - +email_id+ -> ID of the email to send
    #   - +to+ -> Hash of recipient details
    # * *Options*    :
    #   - +:data+ -> Hash of email data
    #   - +:from+ -> Hash of sender details
    #   - +:cc+ -> Array of CC recipients
    #   - +:bcc+ -> Array of BCC recipients
    #   - +:files+ -> Array of attachments
    #   - +:esp_account+ -> The ESP account to use
    #   - +:version_name+ -> The specific email version to use
    #   - +:headers+ -> Hash of headers
    #   - +:tags+ -> Array of tags
    #   - +:locale+ -> Localization string
    # * *Notes*    :
    #   - "send" is already a ruby-defined method on all classes
    #
    def send_email(email_id, to, options = {})
      payload = prepare_email_payload(email_id, to, options)

      api_request.post(:send, payload.to_json)
    end

    # Send a set of emails in a batch request
    # * *Args*    :
    #   - +email_params_sets+ -> an array where each item is an array of +email_id+, +to+, and +options+
    # * *Notes*   :
    #   - For more information about what should be in each item of email_params_sets, see +send_email+ documentation
    #
    def send_emails(email_params_sets)
      requests = email_params_sets.map do |email_params|
        {
          endpoint: :send,
          method: :post,
          payload: prepare_email_payload(*email_params)
        }
      end

      batch_send(requests)
    end

    def drips_unsubscribe(email_address)
      if email_address.nil?
        raise SendWithUs::ApiNilEmailId, 'email_address cannot be nil'
      end

      payload = {email_address: email_address}

      payload = payload.to_json
      api_request.post(:'drips/unsubscribe', payload)
    end

    def emails()
      api_request.get(:emails)
    end

    alias list_templates emails

    def render(template_id, version_id = nil, template_data = {})
      locale = template_data.delete(:locale)

      payload = {
        template_id: template_id,
        template_data: template_data,
      }

      payload[:version_id] = version_id if version_id
      payload[:locale] = locale if locale

      payload = payload.to_json
      api_request.post(:'render', payload)
    end

    def create_template(name, subject, html, text)
      payload = {
        name: name,
        subject: subject,
        html: html,
        text: text
      }

      payload = payload.to_json
      api_request.post(:emails, payload)
    end

    def list_drip_campaigns()
      api_request.get(:drip_campaigns)
    end

    def start_on_drip_campaign(recipient_address, drip_campaign_id, email_data={}, locale=nil, tags=[])
      payload = {recipient_address: recipient_address}

      if email_data && email_data.any?
        payload[:email_data] = email_data
      end
      if tags.any?
        payload[:tags] = tags
      end
      if locale
        payload[:locale] = locale
      end

      payload = payload.to_json
      endpoint = "drip_campaigns/#{drip_campaign_id}/activate"
      api_request.post(endpoint, payload)
    end

    def remove_from_drip_campaign(recipient_address, drip_campaign_id)
      payload = {
        recipient_address: recipient_address
      }

      payload = payload.to_json
      api_request.post("drip_campaigns/#{drip_campaign_id}/deactivate", payload)
    end

    def drip_campaign_details(drip_campaign_id)
      api_request.get("drip_campaigns/#{drip_campaign_id}")
    end

    def list_customers_on_campaign(drip_campaign_id)
      api_request.get("drip_campaigns/#{drip_campaign_id}/customers")
    end

    def list_customers_on_campaign_step(drip_campaign_id, drip_campaign_step_id)
      api_request.get("drip_campaigns/#{drip_campaign_id}/step/#{drip_campaign_step_id}/customers")
    end

    def customer_get(email)
      api_request.get("customers/#{email}")
    end

    def customer_create(email, data = {}, locale = nil)
      payload = {email: email}

      payload[:data] = data if data && data.any?
      payload[:locale] = locale if locale

      payload = payload.to_json
      endpoint = "customers"
      api_request.post(endpoint, payload)
    end

    def customer_delete(email_address)
      endpoint = "customers/#{email_address}"
      api_request.delete(endpoint)
    end

    def customer_email_log(email_address, options = {})
      endpoint = "customers/#{email_address}/logs"
      params   = {}

      params[:count]       = options[:count]       unless options[:count].nil?
      params[:created_gt]  = options[:created_gt]  unless options[:created_gt].nil?
      params[:created_lt]  = options[:created_lt]  unless options[:created_lt].nil?

      unless params.empty?
        params   = URI.encode_www_form(params)
        endpoint = endpoint + '?' + params
      end

      api_request.get(endpoint)
    end

    def logs(options = {})
      endpoint = 'logs'
      params   = {}

      params[:count]       = options[:count]       unless options[:count].nil?
      params[:offset]      = options[:offset]      unless options[:offset].nil?
      params[:created_gt]  = options[:created_gt]  unless options[:created_gt].nil?
      params[:created_gte] = options[:created_gte] unless options[:created_gte].nil?
      params[:created_lt]  = options[:created_lt]  unless options[:created_lt].nil?
      params[:created_lte] = options[:created_lte] unless options[:created_lte].nil?

      unless params.empty?
        params   = URI.encode_www_form(params)
        endpoint = endpoint + '?' + params
      end

      api_request.get(endpoint)
    end

    def log(log_id)
      endpoint = "logs/#{log_id}"

      api_request.get(endpoint)
    end

    def delete_template(template_id)
      endpoint = "templates/#{template_id}"
      api_request.delete(endpoint)
    end

    def list_template_versions(template_id)
      endpoint = "templates/#{template_id}/versions"
      api_request.get(endpoint)
    end

    def get_template_version(template_id, version_id)
      endpoint = "templates/#{template_id}/versions/#{version_id}"
      api_request.get(endpoint)
    end

    def update_template_version(template_id, version_id, name, subject, html, text)
      payload = {
        name: name,
        subject: subject,
        html: html,
        text: text
      }

      endpoint = "templates/#{template_id}/versions/#{version_id}"
      api_request.put(endpoint, payload.to_json)
    end

    def create_template_version(template_id, name, subject, html, text)
      payload = {
        name: name,
        subject: subject,
        html: html,
        text: text
      }

      endpoint = "templates/#{template_id}/versions"
      api_request.post(endpoint, payload.to_json)
    end

    private

    def api_request
      SendWithUs::ApiRequest.new(@configuration)
    end

    # Batch send a set of requests
    # Each request should be a hash containing:
    # - +endpoint+ -> The endpoint you want to go to. NOTE: this is not the full path, it will be converted to a path.
    # - +method+ -> The http method you want to use (:get, :post, :put, etc)
    # - +payload+ -> The payload you want sent with the request. This should NOT be to_json yet.
    def batch_send(requests)
      unless requests.all? { |request| ([:endpoint, :method, :payload] - request.keys).empty? }
        raise 'Each request must be a hash containing :endpoint, :method, and :payload keys'
      end

      normalized = requests.map do |request|
        {
          path: ApiRequest.request_path(@configuration, request[:endpoint]),
          method: request[:method].to_s.upcase,
          body: request[:payload]
        }
      end
      api_request.post(:batch, normalized.to_json)
    end

    def prepare_email_payload(email_id, to, options = {})
      if email_id.nil?
        raise SendWithUs::ApiNilEmailId, 'email_id cannot be nil'
      end

      payload = {
        email_id: email_id,
        recipient: to
      }

      if options[:data] && options[:data].any?
        payload[:email_data] = options[:data]
      end
      if options[:from] && options[:from].any?
        payload[:sender] = options[:from]
      end
      if options[:cc] && options[:cc].any?
        payload[:cc] = options[:cc]
      end
      if options[:bcc] && options[:bcc].any?
        payload[:bcc] = options[:bcc]
      end
      if options[:esp_account]
        payload[:esp_account] = options[:esp_account]
      end
      if options[:version_name]
        payload[:version_name] = options[:version_name]
      end
      if options[:headers] && options[:headers].any?
        payload[:headers] = options[:headers]
      end
      if options[:tags] && options[:tags].any?
        payload[:tags] = options[:tags]
      end
      if options[:locale]
        payload[:locale] = options[:locale]
      end

      if options[:files] && options[:files].any?
        payload[:files] = []

        options[:files].each do |file_data|
          if file_data.is_a?(String)
            attachment = SendWithUs::Attachment.new(file_data)
          else
            attachment = SendWithUs::Attachment.new(file_data[:attachment], file_data[:filename])
          end
          payload[:files] << { id: attachment.filename, data: attachment.encoded_data }
        end
      end

      payload
    end
  end
end
