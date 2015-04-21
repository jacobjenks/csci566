#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'mturk'
require 'sqlite3'

@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Sandbox

# Use this line instead if you want the production website.
#@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Production

@base_directory = File.join(File.expand_path(File.dirname(__FILE__)), "../")
@db = SQLite3::Database.open base_directory+"db/food_dev.db"

#Make sure answers make sense
#Response must have at least one answer, and no conflicting answers.
#@param answer: a simplified answer
#@return: true for valid answer false for invalid answer	
def validateAnswer(answers)
	result = true
	if(answers.length == 0)#require an answer
		return false
	end
	
	answers.each do |answer|
		if(/Q|q/ =~ answer && answers.length > 1)#Invalid response, since this indicates them rejecting category and then choosing from it
			result = false
		end
	end
	
	return result
end

#Get hits awaiting review, and approve or reject answers
def processReviewableHits
	puts "--Processing reviewable HITs--"
	approved = 0
	reject = 0
	#Get reviewable hits
	reviewable = @mturk.getReviewableHITs()

	#Get assignments awaiting approval, and validate
	reviewable[:HIT].each do |hit|
		#get responses
		answers = @mturk.getAssignmentsForHIT(:HITId => hit[:HITId])
		
		if(answers[:NumResults] > 0)
			#validate each response in hit
			answers[:Assignment].each do |assign|
				if(assign[:AssignmentStatus]=='Submitted')
					if(validateAnswer(@mturk.simplifyAnswer(assign[:Answer])))
						@mturk.approveAssignment(:AssignmentId => assign[:AssignmentId], :RequesterFeedback => "Thanks!")#Approve
						approved += 1
					else
						@mturk.rejectAssignment(:AssignmentId =>  assign[:AssignmentId], :RequesterFeedback => "Your answer was invalid or had conflicts.")#Reject
						reject += 1
					end
				end
			end
		end
	end
	puts "     Approved: " + approved.to_s
	puts "     Rejected: " + reject.to_s
end


#Get reviewable hits, and force expire early if consensus has been reached
def earlyExpire
	reviewable = @mturk.getReviewableHITs()
end

#get all hits and their status
def getHITs
	hits = @mturk.searchHITsAll.collect{|hit| hit[:HITId] }
	result = Array.new
	hits.each do |id|
		puts @mturk.getHIT(HITId => id)
	end
end

def createNewHIT(question, imageURL)
	title = "Food Classification"
	desc = "The purpose of this task is to determine the types of food contained within the given image"
	keywords = "food, classification"
	numAssignments = 5
	rewardAmount = 0.05 # 5 cents

	# Define the location of the externalized question (QuestionForm) file.
	questionFile = @base_directory+"questions/food_#{question}.question"

	# Load the question (QuestionForm) file
	question = File.read( questionFile )
	question = question.gsub(/\$imageURL/, imageURL)

	result = @mturk.createHIT( :Title => title,
	:Description => desc,
	:MaxAssignments => numAssignments,
	:Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
	:Question => question,
	:Keywords => keywords )

	@db.prepare("INSERT INTO hit (image_id, task_tier, hit_id) VALUES ('#{row[0]}', 'question', '#{hit[:HITId]}')").execute

	puts "Created HIT: #{result[:HITId]}"
	puts "HIT Location: #{getHITUrl( result[:HITTypeId] )}"

	return result
end

def getHITUrl( hitTypeId )
  if @mturk.host =~ /sandbox/
    "http://workersandbox.mturk.com/mturk/preview?groupId=#{hitTypeId}"   # Sandbox Url
  else
    "http://mturk.com/mturk/preview?groupId=#{hitTypeId}"   # Production Url
  end
end

#Determine which tasks need to be created, and create them
def genTasks
	#Tier 0 tasks
	result = db.prepare("SELECT * FROM image WHERE id NOT IN(SELECT image_id FROM hit)").execute

	i = 0
	result.each do |row|
		i += 1
		hit = createNewHIT('', row[1])
	end

	puts ""
	puts "Created #{i} hits"
end

################ Main ################
#processReviewableHits
#earlyExpire
genTasks

#puts @mturk.searchHITsAll.collect{|hit| hit[:HITId] }.length
#getHits