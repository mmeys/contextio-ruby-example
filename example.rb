#!/usr/bin/env ruby
require 'pry'
require_relative 'contextio'

resource_url = nil

#The ContextIO library uses Faraday. Every time we are interested in Faraday's response body, we call .body on the returned responses.

puts "************* starting ************ "

#All calls to ContextIO must be authenticated. The Ruby library handles authentication for you through your consumer key and consumer secret.

puts "Enter your consumer key. It's located at https://console.context.io/#settings and will look something like '070p7n1x'. hit <ENTER> after each response."
api_key = gets.delete("\n")


puts "Next enter your consumer secret. It'll look something like 'XXXzSCZAztUdXXXX'"
api_secret = gets.delete("\n")

cio = ContextIO.new(api_key, api_secret)

puts
puts "Go to http://requestb.in and create a new private bin. We will use that as the callback_url"
puts "Enter the callback_url here. It'll look like 'http://requestb.in/xxpk9sxx'"
puts "type SKIP if you don't want to connect a new account"
callback_url = gets.delete("\n")

if callback_url != "SKIP"

puts
puts "Now enter an email address you want to connect. We recommend using a sample Gmail address with some emails in it. Open a browser tab and make sure you're logged into that email via the web interface."
throwaway_gmail = gets.delete("\n")

#Here we're actually making the request to create the account with connect_tokens via POST https://api.context.io/lite/connect_tokens?callbackurl=&email

response = cio.request(:post, "https://api.context.io/lite/connect_tokens", {callback_url: callback_url, email:throwaway_gmail}).body

puts
if response['success'] == true
  puts response.inspect
  redirect_url = response['browser_redirect_url']
  puts "Open a browser tab and paste in this URL: #{redirect_url} This is the redirect url you will need to redirect your user to for them to authenticate. Go ahead and authenticate via the redirect_url. Once you do, you'll be redirected to your request bin callback_url, which will show a 'ok'"
  puts "Hit ENTER when you've completed this step."
  gets
  puts "Refresh request bin and append ?inspect after the URL to see that something came through:  #{callback_url}?inspect"

  # Intsead of request bin, your callback_url should be where you want to the user to go in your application after they authenticate.

  #Now that the user has been created, you can go to https://console.context.io/#accounts and see the user listed with their user id and email addresss. You will need the user id in order to make calls to the API. (User ids are unique, and they are tied to your developer key.)

  puts "We will now query ContextIO using the ?contextio_token value from Gmail's postback to get the user id and other information needed to make an API call."
  response = cio.request(:get, "https://api.context.io/lite/connect_tokens/#{response['token']}", {}).body

  resource_url = response['']['email_accounts'].first['resource_url']
  puts "Hit enter to get some data from this email account!"
  gets
else
  puts "There was a problem with the connect token call."
  puts "The response body was"
  puts response.inspect
  puts "...exiting..."
  exit 1
end

end

#If you skipped creating an account, this is where you'll go.

if resource_url.nil?
  response = cio.request(:get, 'https://api.context.io/lite/users', {}).body
  resource_url = response.last['email_accounts'].first['resource_url']
end

if response.is_a?(::Hash) && response['type']=="error"
  puts "There was a problem making the call. The error message is >> #{response['value']} << Your credentials were probably invalid. Exiting."
  exit 1
end

# To get a list of a user's email folders, GET https://api.context.io/lite/users/:id/email_accounts/:label/folders

folders = cio.request(:get, "#{resource_url}/folders", {}).body

puts
puts "Listing folders"
folders.each {|f| puts f['name']}

# Fetch a list of messages in the INBOX folder: GET https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages

messages = cio.request(:get, "#{resource_url}/folders/INBOX/messages", {}).body

puts
puts "Listing message subjects"
messages.each { |m| puts m['subject'] }


# View an individual message: GET https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages/:message_id/body

random_message = messages.sample

puts
puts "Fetching message body... please wait..."
random_message_body = cio.request(:get, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/body", {}).body

puts "Printing message body for email with subject '#{random_message['subject']}' with email_message_id #{random_message['email_message_id']}"

# Message bodies can come in multiple types. Most commonly, they are text/plain and text/html. Let's print out the contents.

puts random_message_body.first['content']

# Set flags for a message: POST https://api.context.io/lite/users/:id/email_accounts/:label/folders/:folder/messages/:message_id/read
puts
puts "Setting read flag on message"
response = cio.request(:post, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/read", {}).body
puts response.inspect


# Show the current flags on that message to make sure the read flag is set: GET https://api.context.io/lite/users/id/email_accounts/label/folders/folder/messages/message_id/flags
puts
puts "Getting message flags"
response = cio.request(:get, "#{resource_url}/folders/INBOX/messages/#{random_message['email_message_id']}/flags", {}).body
puts response.inspect

1.upto(10) do
  puts
end
puts "************** End of ContextIO demo. Build something amazing! **************"
