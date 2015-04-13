#!/usr/bin/env ruby

# This sample application creates a simple HIT using Libraries for Amazon Web Services.
# Example taken from http://docs.aws.amazon.com/AWSMechTurk/latest/AWSMechanicalTurkGettingStartedGuide/CreatingAHIT.html#Ruby
#

require 'mturk'
require 'sqlite3'

base_directory = "/home/ec2-user/csci566/"

@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Sandbox

# Use this line instead if you want the production website.
#@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Production




def createNewHIT(imageURL)
  title = "Food Classification"
  desc = "The purpose of this task is to determine the types of food contained within the given image"
  keywords = "food, classification"
  numAssignments = 5
  rewardAmount = 0.05 # 5 cents
  
  # Define the location of the externalized question (QuestionForm) file.
  #rootDir = File.dirname $0
  #questionFile = rootDir + "../questions/food_1.question"
  questionFile = "../questions/food_1.question"

  # Load the question (QuestionForm) file
  question = File.read( questionFile )
  question = question.gsub(/\$imageURL/, imageURL)
  
  puts question
  
  #result = @mturk.createHIT( :Title => title,
  #  :Description => desc,
  #  :MaxAssignments => numAssignments,
  #  :Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
  #  :Question => question,
  #  :Keywords => keywords )

  #puts "Created HIT: #{result[:HITId]}"
  #puts "HIT Location: #{getHITUrl( result[:HITTypeId] )}"
  
  #return result
end

def getHITUrl( hitTypeId )
  if @mturk.host =~ /sandbox/
    "http://workersandbox.mturk.com/mturk/preview?groupId=#{hitTypeId}"   # Sandbox Url
  else
    "http://mturk.com/mturk/preview?groupId=#{hitTypeId}"   # Production Url
  end
end


db = SQLite3::Database.open base_directory+"db/food.db"
result = db.prepare("Select * FROM image").execute

result.each do |row|
	puts row.join "\s"
end
	
#createNewHIT('www.test.com/test.jpg')


