module LinkedIn
  class Client
    
    attr_reader :ctoken, :csecret, :consumer_options
    
    def initialize(ctoken, csecret, options={})
      opts = { 
              :request_token_path => "/uas/oauth/requestToken",
              :access_token_path  => "/uas/oauth/accessToken",
              :authorize_path     => "/uas/oauth/authorize"
            }
      @ctoken, @csecret, @consumer_options = ctoken, csecret, opts.merge(options)
    end
    
    def consumer
      @consumer ||= ::OAuth::Consumer.new(@ctoken, @csecret, {:site => 'https://api.linkedin.com'}.merge(consumer_options))
    end
    
    def set_callback_url(url)
      clear_request_token
      request_token(:oauth_callback => url)
    end
    
    # Note: If using oauth with a web app, be sure to provide :oauth_callback.
    # Options:
    #   :oauth_callback => String, url that twitter should redirect to
    def request_token(options={})
      @request_token ||= consumer.get_request_token(options)
    end
    
    # For web apps use params[:oauth_verifier], for desktop apps,
    # use the verifier is the pin that twitter gives users.
    def authorize_from_request(rtoken, rsecret, verifier_or_pin)
      request_token = ::OAuth::RequestToken.new(consumer, rtoken, rsecret)
      access_token = request_token.get_access_token(:oauth_verifier => verifier_or_pin)
      @atoken, @asecret = access_token.token, access_token.secret
    end
    
    def access_token
      @access_token ||= ::OAuth::AccessToken.new(consumer, @atoken, @asecret)
    end
    
    def authorize_from_access(atoken, asecret)
      @atoken, @asecret = atoken, asecret
    end
    
    def get(path, options={})
      path = "/v1#{path}"
      puts path
      response = access_token.get(path, options)
      raise_errors(response)
      parse(response)
    end
    
    
    def profile(options={})
      
      path = person_path(options)
      
      unless options[:fields].nil?
        if options[:public] 
          path +=":public"
        else
          path +=":(#{options[:fields].map{|f| f.to_s}.join(',')})"
        end
      end
      data = Hashie::Mash.new(get(path))
      
      if data.errors.nil?
        data.person
      else
        data
      end

    end
    
    def connections(options={})
      path = "#{person_path(options)}/connections"
      
      unless options[:fields].nil?
        if options[:public] 
          path +=":public"
        else
          path +=":(#{options[:fields].map{|f| f.to_s}.join(',')})"
        end
      end
      
      data = Hashie::Mash.new(get(path))
      
      if data.errors.nil?
        data.connections
      else
        data
      end

    end
    
    private
      def clear_request_token
        @request_token = nil
      end
      
      def raise_errors(response)
        case response.code.to_i
          when 502..503
            raise Unavailable, "(#{response.code}): #{response.message}"
        end
      end

      def parse(response)
        Crack::XML.parse(response.body)
      end
      
      def person_path(options)
        path = "/people/"
        if options[:id]
          path += "id=#{options[:id]}"
        elsif options[:email]
          path += "email=#{options[:email]}"
        elsif options[:url]
          path += "url=#{CGI.escape(options[:url])}"
        else
          path += "~"
        end
      end


    
  end
end