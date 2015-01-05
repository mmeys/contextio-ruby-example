#!/usr/bin/env ruby
require 'pry'
require_relative 'contextio'

resource_url = nil

#note the contextio library uses faraday. pretty much every time, we are interested in faraday's response body so we'll call .body on returned responses from faraday
puts "************* starting ************ "

puts "OK First enter your developer key. It's located at https://console.context.io/#settings and will look something like '070p7n1x'. hit <ENTER> after each response."
api_key = gets.delete("\n")


puts "Next enter your developer password. It'll look something like 'XXXzSCZAztUdXXXX'"
api_password = gets.delete("\n")

cio = ContextIO.new(api_key, api_password)

#now lets add a user and connect an email inbox using connect_tokens
#we have to provide the callbackurl and the email address that we want to connect to the new user
#POST https://api.context.io/lite/connect_tokens?callbackurl=&email

puts
puts "Go go http://requestb.in and create a new private requestb.in"
puts "Enter the callback url here. It'll look like 'http://requestb.in/1lpk9sb3'"
puts "type SKIP if you dont want to connect a new account"
callback_url = gets.delete("\n")

if callback_url != "SKIP"

puts
puts "Now enter an email address you want to connect. Choose a throwaway gmail with some emails in it. Open a browser tab and make sure you're logged into that email via the web interface."
throwaway_gmail = gets.delete("\n")

#lets make the call to add a connect_token for this account
response = cio.request(:post, "https://api.context.io/lite/connect_tokens", {callback_url: callback_url, email:throwaway_gmail}).body

puts
if response['success'] == true
  puts response.inspect
  redirect_url = response['browser_redirect_url']
  puts "Open a browser tab and paste in this URL. #{redirect_url} Your ISP will ask you if you're sure you want Context.IO to access your email. Confirm that you do. You'll be redirected to your Requestb.in which will show a 'ok'"
  puts "Hit ENTER when you're done with this step."
  gets
  puts "Refresh your requestb.in (append ?inspect after the URL) and inspect that something came through:  #{callback_url}?inspect"
  # Instead of going to Requestb.in you would put url on your own server to then do something meaningful like fetch their latest emails"
  # But before you can do that, you need to query context.io to get their id in our system because you need to at least know that to do a API call."
  
  #At this point, you could go into the developer console to the accounts tab @ https://console.context.io/#accounts and see that the User account is created and their email is attached"
  #Now this User and this email address are connected to your Developer account in context.io"
  puts "Lets query context.io using the ?contextio_token value from Gmail's postback. to get teh new users's id and server label which we need for all API calls"
  response = cio.request(:get, "https://api.context.io/lite/connect_tokens/#{response['token']}", {}).body

  resource_url = response['']['email_accounts'].first['resource_url']
  puts "Hit enter to get some data from this email account!"
  gets
else
  puts "there was a problem with the connect token call. i can't go on."
  puts "the response body was"
  puts response.inspect
  puts "exiting"
  exit 1
end

end

#print out folders
# GET https://api.context.io/lite/users/:id/email_accounts/:label/folders

#if you SKIPped the connect token thing above then lets grab the last user in your acount's resource URL
if resource_url.nil?
  response = cio.request(:get, 'https://api.context.io/lite/users', {}).body
  resource_url = response.last['email_accounts'].first['resource_url']
end

if response.is_a?(::Hash) && response['type']=="error"
  puts "There was a problem making the call. The error message is >> #{response['value']} << Your credentials were probably invalid. Exiting."
  exit 1
end


# we have enough info to make the folders API call
folders = cio.request(:get, "#{resource_url}/folders", {}).body

puts
puts "Listing folders"
folders.each {|f| puts f['name']}

#fetch a list of messages in the INBOX folder
#GET https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages
#we have all the info needed to fill in :id, :label, :folder so we can make the API call
messages = cio.request(:get, "#{resource_url}/folders/INBOX/messages", {}).body

puts
puts "Listing message subjects"
messages.each { |m| puts m['subject'] }


#view an individual message
#GET https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages/:message_id/body
#We hvae all the info we need except the individual message_id. Lets get that from a random message.
random_message = messages.sample

puts
puts "Fetching message body.. please wait..."
#now we can fill in the :message_id and make the API call
random_message_body = cio.request(:get, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/body", {}).body

puts "Printing message body for email with subject '#{random_message['subject']}' with email_message_id #{random_message['email_message_id']}"
#message bodies can come in multiple types. most commonly, there are usually text/plain and a text/html parts. lets print out the first one's contents
puts random_message_body.first['content']

#now lets set the read flag on this message
#POST https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages/:message_id/read
puts
puts "Setting read flag on message"
response = cio.request(:post, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/read", {}).body
puts response.inspect


#finally lets show the current flags on that message to make sure the read flag is set
#GET https://api.context.io/lite/users/id/email_accounts/label/folders/folder/messages/message_id/flags
puts
puts "Getting flags on message"
response = cio.request(:get, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/flags", {}).body
puts response.inspect

1.upto(10) do
  puts
end
puts "************** done with context.io demo now go build something! **************"
