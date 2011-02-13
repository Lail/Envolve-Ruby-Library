require 'hmac-sha1'
require 'digest/sha1'
require 'base64'

module EnvolveChat
  
  # Envolve API module to create signed commands and javascript tags to interact
  # with Envolve chat service.
  
  # This is free software intended for integrating your custom ruby
  # software with Envolve's website chat software. You may do with this 
  # software as you wish.
  #
  # Licensed under the Apache License, Version 2.0 (the "License");
  # you may not use this file except in compliance with the License.
  # You may obtain a copy of the License at
  #
  #     http://www.apache.org/licenses/LICENSE-2.0
  #
  # Unless required by applicable law or agreed to in writing, software
  # distributed under the License is distributed on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  # See the License for the specific language governing permissions and
  # limitations under the License.
  
  # Created by Lail Brown <http://github.com/lailbrown>
  # Borrows heavily from the Python module originaly created by Matt Wood <http://github.com/mattwood>
  
  ENVOLVE_API_VERSION = '0.2'
  ENVOLVE_JS_ROOT = 'http://d.envolve.com/env.nocache.js'
  
  class ChatRenderer

    def self.get_html(envolve_api_key, args = {} )

      # Returns the javascript tags necessary to use the Envolve API login mechanism.


      # envolve_api_key -- your site's Envolve API key as a string
      
      # Command arguments:
      
      # first_name -- optional string for the user's first name.
      #               Default value: None.
      # last_name -- optional string for the user's last name.
      #               Default value: None.
      # pic -- optional string of the absolute URL to the user's avatar.
      #        Default value: None.
      # is_admin -- optional boolean for the user's admin status.
      #               Default value: False.
      
      # Option arguments:
      
      # people_here_text -- optional text used to customize the "X People Here" message
      #             Default value: none
      # people_list_header_text -- optional text used to customize the "Chat with people on this site" message
      #             Default value: none
      # enable_socialgo --  optional boolean to enable login for SocialGo
      #             Default value: false
      # groups -- array of hashes containing values for :id and :name

      # For more information on options:
      #    http://www.envolve.com/api/developer-api-options.html


      # If first_name is not passed in, the user will be anonymous.

      # To use in a Rails app, make sure you have the hmac-sha1 gem and add this module to your /lib folder. 
      # Then call EnvolveChat::ChatRenderer.get_html 
      # from a view or helper with the appropriate keywords specified. The function will
      # return javascript that you can use in your page's HTML.

      # This ruby code:
      
      ## in Gemfile      
      #     gem "ruby-hmac"

      
      ## in view or helper
      #   EnvolveChat::ChatRenderer.get_html("123-abcdefghijklmnopqrs", 
      #     :first_name => user.first_name,
      #     :last_name => user.last_name,
      #     :is_admin => user.admin, 
      #     :pic => user.avatar(:itty_bitty), 
      #     :people_list_header_text => "Chat with site visitors",
      #     :people_here_text => "People online",
      #     :groups => [{:id => "forum_sec", :name => "Forum Chat"}]
      #   )
      
      # will produce javascript similar to:

      #     <script type="text/javascript">
      #         envoSn=123;
      #         env_commandString="{ command string }";
      #         envoOptions={peopleHereText : 'People online',peopleListHeaderText : 'Chat with site visitors',groups : [{id : 'forum_sec', name : 'Forum Chat'}]};
      #     </script>
      #     <script type="text/javascript" src="http://d.envolve.com/env.nocache.js"></script>

      args = {
        :first_name => nil,
        :last_name => nil,
        :pic => nil,
        :is_admin => false
      }.merge(args)

      first_name = args.delete(:first_name)

      api_key = EnvolveChat::EnvolveAPIKey.new(envolve_api_key)
      if first_name
        return get_html_for_command(api_key,
                                    get_options(args), 
                                    get_login_command(api_key.full_key,
                                                      first_name, 
                                                      args))
      else
        return get_html_for_command(api_key, get_options(args))
      end                              
    end
  
    def self.get_login_command(envolve_api_key,first_name, args = {})
      # Returns the hashed login command string for use in the javascript call
      # to the Envolve API.
    
      # Keyword argument:
      # envolve_api_key -- your site's Envolve API key as a string
      # first_name -- string for the user's first name.
      # last_name -- optional string for the user's last name.
      #              Default value: None.
      # pic -- optional string for the user's avatar.
      #        Default value: None.
      # is_admin -- optional boolean for the user's admin status.
      #             Default value: False.
    
      api_key = EnvolveChat::EnvolveAPIKey.new(envolve_api_key)
      raise EnvolveChat::EnvolveAPIError.new "You must provide at least a first name. If you are providing a username, use it for the first name." unless first_name
 
      command = [
        "v=#{ENVOLVE_API_VERSION}",
        "c=login",
        "fn=#{encode_to_spec first_name}"
      ]
      command << "ln=#{encode_to_spec args[:last_name]}" if args[:last_name]
      command << "pic=#{encode_to_spec args[:pic]}" if args[:pic]
      command << "admin=#{args[:is_admin] ? 't' : 'f' }"
    
      return wrap_command(api_key, command.join(","))
    end
    
    def self.get_logout_command(envolve_api_key)
      # Returns the hashed logout command string for use in the javascript call to the Envolve API.

      # Keyword argument:
      # envolve_api_key -- your site's Envolve API key as a string

      api_key = EnvolveAPIKey(envolve_api_key)
      return wrap_command(api_key, "c=logout")
    end
    
    private
    
    def self.encode_to_spec(str)
      # Returns a base64-encoded string based on the Envolve specifications.
      Base64.encode64(str).gsub("+", "-").gsub("/", "_").chomp.gsub(/\n/,'')
    end
    
    def self.wrap_command(api_key,command)
      # Returns the hashed command string to perform calls to the API.
    
      # Keyword arguments:
      # api_key -- EnvolveAPIKey object
      # command -- plaintext command string
    
      k = api_key.secret_key
      t = Time.now.to_i * 1000 # milliseconds since epoch
      h = HMAC::SHA1.hexdigest(k,"#{t};#{command}") 
    
      return "#{h};#{t};#{command}"
    end
    
    def self.get_html_for_command(api_key, opts = nil, command = nil)
    
      # Returns the javascript tags for a given hashed command.

      # Keyword arguments:
      # api_key -- EnvolveAPIKey object
      # opts -- array of options
      # command -- Hashed command string for which to return the javascript.

      js = ['<script type="text/javascript">',
            "envoSn=#{api_key.site_id};"]
      js << "env_commandString='#{command}';" if command
      js << get_html_for_options(opts) if opts
      js << "</script>"
      js << "<script type='text/javascript' src='#{ENVOLVE_JS_ROOT}'></script>"
              
      return js.join "\n"
    end
  
    def self.get_html_for_options(opts)
      
      if opts.length != 0
        o = []
          opts.each do |opt|
            #raise EnvolveChat::EnvolveAPIError.new "***************************** : #{opt[0]}"
          case opt[0].to_s
            when "people_here_text"
              o << "peopleHereText : '#{opt[1]}'"
            when "people_list_header_text"
              o << "peopleListHeaderText : '#{opt[1]}'"
            when "enable_socialgo"
              o << "enableSocialGo : '#{opt[1].to_s}'"
            when "groups"
              groups = []
                opt[1].each do |group|
                  groups << "{id : '#{group[:id]}', name : '#{group[:name]}'}"
                end
             o << "groups : [#{groups.join(',')}]"
          end
          end
        return "envoOptions={#{o.join(',')}};"
      end
    end
    
    def self.get_options(args)
      return args.select {|k,v| ["people_here_text","people_list_header_text","enable_socialgo","groups"].include? k.to_s }
    end
  
  end # close class
  
  class EnvolveAPIError < StandardError
  end

  class EnvolveAPIKey
    attr_accessor :site_id
    attr_accessor :secret_key
    attr_accessor :full_key
    
    def initialize(api_key)
      # Handles encapsulation and validation of the Envolve API key.

      # Keyword arguments:
      # api_key -- optional string argument that defaults to ENVOLVE_API_KEY.
      begin
        api_key_pieces = api_key.strip.split('-')
        raise EnvolveChat::EnvolveAPIError.new "Invalid or missing Envolve API Key." unless ( api_key_pieces.size == 2 and api_key_pieces[0].length > 0 and api_key_pieces[1].length > 0 )
      rescue
        raise EnvolveChat::EnvolveAPIError.new "Invalid or missing Envolve API Key."
      end

      self.site_id = api_key_pieces[0]
      self.secret_key = api_key_pieces[1]
      self.full_key = "#{self.site_id}-#{self.secret_key}"
    end
  end
  
end