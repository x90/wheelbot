module Campfire  
  class Room
    attr_reader :room_id
    
    include HTTParty
    headers     'Content-Type' => 'application/json'
  
    def initialize(room_name, config, campsite)
      @campsite = campsite
      @room_id = campsite.room_id_from_name(room_name)
      @token = config["api_key"]
      @config = config
      
      Room.base_uri    "https://#{config['subdomain']}.campfirenow.com"
      Room.basic_auth  "#{@token}", "x"
    end
  
    def join
      post 'join'
    end
  
    def speak(message)
      send_message message
    end
  
    def listen(handlers)
      options = {
        :path => "/room/#{@room_id}/live.json",
        :host => 'streaming.campfirenow.com',
        :auth => "#{@token}:x"
      }
    
      EventMachine::run do
        stream = Twitter::JSONStream.connect(options)

        stream.each_item do |item|
          msg = JSON.parse(item)
          unless msg["user_id"] == @campsite.me["id"]
            if /^#{@config["bot_name"]}:/i.match(msg["body"])
              CampfireBot::Message.new(msg["body"], self, handlers)
            # elsif /ni!/i.match(msg)
            #   @room.speak("Do you demand a shrubbery?")
            end
          end
        end

        stream.on_error do |message|
          puts "ERROR:#{message.inspect}"
        end

        stream.on_max_reconnects do |timeout, retries|
          puts "Tried #{retries} times to connect."
          exit
        end
      end
    end
  
    private
  
    def send_message(message, type = 'Textmessage')
      post 'speak', :body => {:message => {:body => message, :type => type}}.to_json
    end
  
    def post(action, options = {})
      Room.post room_url_for(action), options
    end
  
    def room_url_for(action)
      "/room/#{room_id}/#{action}.json"
    end
  end
end