
require 'rubygems'
require 'bundler/setup'
require 'httpclient'
require 'json'
require 'psych'

LAST_ACTION_ID_FILENAME="last_action_id"
CONFIG_FILENAME="trello-hipchat.yml"

@config = Psych.load_file(File.join(File.dirname(File.expand_path(__FILE__)), CONFIG_FILENAME))
@http ||= HTTPClient.new
@last_id = 0


def send_to_hipchat(msg, format="html")
  data = {
    from: :Trello,
    message: msg,
    message_format: format,
    color: @config["hipchat"]["color"],
    room_id: @config["hipchat"]["room"]
  }
  @http.post "https://api.hipchat.com/v1/rooms/message?format=json&auth_token=#{@config["hipchat"]["api_key"]}", data
end

def trello_full_path(path)
  "https://api.trello.com/1#{path}?token=#{@config["trello"]["token"]}&key=#{@config["trello"]["api_key"]}"
end

def trello_activity
  check_activity = (@last_id == 0)
  activities = JSON.parse(@http.get_content trello_full_path("/boards/#{@config["trello"]["board_id"]}/actions")+"&limit=1000")
  activities.reverse.each do |act|
    if act["id"] == @last_id
      check_activity = true
      next
    elsif check_activity == false
      next
    end

    begin
      card_id_short = act["data"]["card"]["idShort"]
      card_id = act["data"]["card"]["id"]
      card_url = "https://trello.com/card/#{card_id}/#{@config["trello"]["board_id"]}/#{card_id_short}"
      card_name = act["data"]["card"]["name"].slice(0, 200)    
      author = act["memberCreator"]["fullName"]
      list_name = JSON.parse(@http.get_content trello_full_path("/cards/#{card_id}/list"))["name"]
    rescue StandardError => e
      $stderr.puts e
      next
    end

    case act["type"]
    when "createCard"
      send_to_hipchat("#{author} created card <a href=\"#{card_url}\">#{card_name}</a> in list #{list_name}")

    when "commentCard"

      text = act["data"]["text"].slice(0, 200)           
      send_to_hipchat("#{author} commented on card <a href=\"#{card_url}\">#{card_name}</a>: #{text}")

    when "addAttachmentToCard"            
      aname = act["data"]["attachment"]["name"]
      aurl = act["data"]["attachment"]["url"]
                    
      send_to_hipchat "#{author} added an attachment to card <a href=\"#{card_url}\">#{card_name}</a>: <a href=\"#{aurl}\">#{aname}</a>"
      send_to_hipchat(aurl, "text") if aurl.end_with?("png", "jpg", "jpeg", "gif")
      
    when "updateCard"
      if act["data"]["old"].key?("idList") and act["data"]["card"].key?("idList")
        # Move between lists
        old_list_id = act["data"]["old"]["idList"]
        new_list_id = act["data"]["card"]["idList"]
        n1 = JSON.parse(@http.get_content trello_full_path("/list/#{old_list_id}"))["name"]
        n2 = JSON.parse(@http.get_content trello_full_path("/list/#{new_list_id}"))["name"]

        send_to_hipchat "#{author} moved card <a href=\"#{card_url}\">#{card_name}</a> from list \"#{n1}\" to list \"#{n2}\""
      end

    when "updateCheckItemStateOnCard"
      if act["data"]["checkItem"]["state"] == "complete"
        name = act["data"]["checkItem"]["name"]
        send_to_hipchat "#{author} completed checklist item \"#{name}\" in card <a href=\"#{card_url}\">#{card_name}</a>"
      end
   end
   File.open(LAST_ACTION_ID_FILENAME, 'w') { |f| f.write act["id"] }
 end
end

@last_id = IO.read(LAST_ACTION_ID_FILENAME) if File.exists? LAST_ACTION_ID_FILENAME
trello_activity
