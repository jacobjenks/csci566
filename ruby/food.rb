#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'mturk'
require 'sqlite3'

#################### Variables ##########################
@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Sandbox

# Use this line instead if you want the production website.
#@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Production

@base_directory = File.expand_path(File.dirname(__FILE__))
@base_directory = @base_directory.gsub(/ruby/, "")
@db = SQLite3::Database.open @base_directory+"db/food_dev.db"

#################### Functions ###########################

#Make sure answers make sense
#Response must have at least one answer, and no conflicting answers.
#@param answer: a simplified answer
#@return: true for valid answer false for invalid answer	
def validateAnswer(answers)
	result = true
	if(answers.length == 0)#require an answer
		return false
	end
	
	answers.each do |key, answer|
		if(/Q|q/ =~ answer.to_s && answers.length > 1)#Invalid response, since this indicates them rejecting category and then choosing from it
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
	
	reviewable = @db.execute("SELECT hit_id FROM hit WHERE complete!=1")

	#Get assignments awaiting approval, and validate
	reviewable.each do |hit|
		#get responses
		answers = @mturk.getAssignmentsForHIT(:HITId => hit)
		if(answers[:NumResults] > 0)
			if(answers[:NumResults] == 1)#fix inconsistent formatting
				puts answers
				puts "HEY YOU FORGOT TO FIX THIS"
				exit
			end
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

#get all hits and their status
#@param status: Filter by HITs with the given status. Options are 'Assignable', 'Unassignable', 'Reviewable', 'Reviewing', and 'Disposed'
def getHITs(status="")
	hits = @mturk.searchHITsAll.collect{|hit| hit[:HITId] }
	result = Hash.new
	hits.each do |id|
		hit = @mturk.getHIT(:HITId => id)
		if(status=="" || hit[:HITStatus]==status)
			result[id] = hit
		end
	end
	puts result
end

#Get HIT answers
#@param status: The status of the answers to recieve. Options are 'Submitted', 'Approved', and 'Rejected'
def getAnswers(hit, status="")
	answers = @mturk.getAssignmentsForHIT(:HITId => hit)
	result = Hash.new
	if(answers[:NumResults] == 1)
		if(status=="" || answers[:AssignmentStatus]==status)
			result[answers[:AssignmentId]] = answers
		end
	elsif(answers[:NumResults] > 1)
		answers[:Assignment].each do |answer|
			if(status=="" || answer[:AssignmentStatus]==status)
				result[answer[:AssignmentId]] = answer
			end
		end
	end
	return result
end

def createNewHIT(questionId, imageId, imageURL)
	title = "Food Classification"
	desc = "The purpose of this task is to determine the types of food contained within the given image."
	keywords = "food, classification"
	numAssignments = 1
	rewardAmount = 0.01

	# Define the location of the externalized question (QuestionForm) file.
	questionFile = @base_directory+"questions/food_#{questionId}.question"

	# Load the question (QuestionForm) file
	question = File.read(questionFile)
	question = question.gsub(/\$imageURL/, imageURL)

	result = @mturk.createHIT( :Title => title,
	:Description => desc,
	:MaxAssignments => numAssignments,
	:Reward => { :Amount => rewardAmount, :CurrencyCode => 'USD' },
	:Question => question,
	:Keywords => keywords )

	@db.execute("INSERT INTO hit (image_id, task_tier, hit_id) VALUES ('#{imageId}', '#{questionId}', '#{result[:HITId]}')")

	#puts "Created HIT: #{result[:HITId]}"
	puts "     HIT Location: #{getHITUrl( result[:HITTypeId] )}"

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
	puts "--Generating new HITs--"
	###### Tier 0 tasks ##########
	result = @db.prepare("SELECT id, url FROM image WHERE id NOT IN(SELECT image_id FROM hit)").execute

	i = 0
	result.each do |row|
		i += 1
		createNewHIT('', row[0], row[1])
	end
	
	####### All other tasks #######
	
	#Check for consensus
	hits = @db.execute("SELECT hit_id FROM hit WHERE complete!=1")
	
	hits.each do |hit|
		hit = hit[0]
		image = @db.get_first_row("SELECT id, url FROM image WHERE id=(SELECT image_id FROM hit WHERE hit_id='#{hit}')")
		hitDetail = @mturk.getHIT(:HITId => hit)
		answers = getAnswers(hit, "Approved")
		consensus = Hash.new
		answers.each do |key, a|
			@mturk.simplifyAnswer(a[:Answer]).each do |key, row|
				row.each do |actualAnswer|
					if(consensus.has_key?(actualAnswer))
						consensus[actualAnswer] += 1
					else
						consensus[actualAnswer] = 1
					end
				end
			end
		end
		
		#do we have a majority vote yet?
		majority = false
		consensus.each do |key, c|
			if(consensus[key] > hitDetail[:MaxAssignments].to_f/2)
				majority = true
			end
		end
		
		#Gen new hits if we have majority or if all questions have been answered
		if(majority || answers.length == hitDetail[:MaxAssignments].to_i)
			if(majority)#quit early if we already have a majority vote
				@mturk.forceExpireHIT(:HITId => hit)
			end
			
			#generate new hits
			consensus.each do |key, c|
				if(c > hitDetail[:MaxAssignments].to_i/2)
					i+=1
					createNewHIT(key, image[0], image[1])
				end
			end
			@db.execute("UPDATE hit SET complete=1 WHERE hit_id='#{hit}'")
		end
		
	end
	
	puts "     Created #{i} hits"
end

################ Main ################
processReviewableHits
genTasks