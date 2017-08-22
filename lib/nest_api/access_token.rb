module NestApi
  class AccessToken
    def initialize(product_id, product_secret, file)
      @product_id = product_id
      @product_secret = product_secret
      @file = file
    end

    def access_token
      auth_code['access_token']
    end

    private

    def auth_code
      @auth_code ||= retrieve_credentials
    end

    # Initiate authorization process to obtain a nest access code
    def authorize
      # Prompt user for pin code -- must be retrieved from online
      puts "Please generate a pin code at #{NestApi::AUTH_URL}#{@product_id} and enter it here:"
      pin = gets.strip

      result = HTTParty.post("#{NestApi::TOKEN_URL}", query: {
          code: pin,
          client_id: @product_id,
          client_secret: @product_secret,
          grant_type: 'authorization_code'
        })

      if Rails.env.development?
        File.open(@file, "w") { |file| file.write(result.to_json) }
      end

      @auth_code = result
    end

    def configuration_error
      raise ConfigurationError, "The config file is either empty or corrupt. Please remove #{@file} from the filesystem and reauthenticate."
    end

    # Read saved nest credentials from a file
    def retrieve_credentials
      if Rails.env.development?
        @auth_code = JSON.parse(File.read(@file))

        if @auth_code['access_token'].nil? || @auth_code['access_token'].empty?
         configuration_error
        end
      else
        if ENV['NEST_API_AUTH_TOKEN'].nil?
          authorize
        else
          @auth_code = {"access_token" => ENV['NEST_API_AUTH_TOKEN']}
        end
      end

      @auth_code

    rescue Errno::ENOENT
      authorize
    rescue JSON::ParserError
      configuration_error
    end
  end
end
