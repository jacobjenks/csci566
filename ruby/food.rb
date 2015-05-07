#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'mturk'
require 'sqlite3'

#################### Variables ##########################
#@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Sandbox
@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Production

@base_directory = File.expand_path(File.dirname(__FILE__))
@base_directory = @base_directory.gsub(/ruby/, "")
#@db = SQLite3::Database.open @base_directory+"db/food_dev.db"
@db = SQLite3::Database.open @base_directory+"db/food.db"

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
				answers[:Assignment] = [answers[:Assignment]]
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

def getHIT(id)
	return @mturk.getHIT(:HITId => id)
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
	return hits
end

#Get HIT answers
#@param status: The status of the answers to recieve. Options are 'Submitted', 'Approved', and 'Rejected'
def getAnswers(hit, status="")
	answers = @mturk.getAssignmentsForHIT(:HITId => hit)
	result = Array.new
	if(answers[:NumResults] == 1)
		if(status=="" || answers[:Assignment][:AssignmentStatus]==status)
			answers[:Answer] = answers[:Assignment][:Answer]
			result << answers
		end
	elsif(answers[:NumResults] > 1)
		answers[:Assignment].each do |answer|
			if(status=="" || answer[:AssignmentStatus]==status)
				result << answer
			end
		end
	end
	return result
end

def createNewHIT(questionId, imageId, imageURL, price, assignments)
	questionId = questionId.to_s
	title = "Food Classification"
	desc = "The purpose of this task is to determine the types of food contained within the given image."
	keywords = "food, classification"

	#Quantity questions contain the question ID + Q, or are asked at the bottom of the tree
	if(/Q|q/ =~ questionId || !File.exist?(@base_directory+"questions/food_#{questionId}.question"))
		trimmedID = /[0-9]*/.match(questionId)[0]
		questionFile = @base_directory+"questions/quantity.question"
		question = File.read(questionFile)
		foodQ = File.read(@base_directory+"questions/food_"+trimmedID.slice(0,trimmedID.length-1)+".question")
		food = /<SelectionIdentifier>#{trimmedID}<\/SelectionIdentifier>[\r\n\t\s]*<Text>([a-zA-Z,. ()-]*)<\/Text>/.match(foodQ)[1].downcase
		question = question.gsub(/\$food/, food)
		question = question.gsub(/\$qId/, trimmedID.to_s+"Q")
	else
		questionFile = @base_directory+"questions/food_#{questionId}.question"
		question = File.read(questionFile)
	end

	question = question.gsub(/\$imageURL/, imageURL)

	begin
		result = @mturk.createHIT( :Title => title,
		:Description => desc,
		:MaxAssignments => assignments,
		:Reward => { :Amount => price, :CurrencyCode => 'USD' },
		:Question => question,
		:Keywords => keywords )
	rescue => error
		puts "     Error parsing "+questionFile
		puts question
		puts "     "+error
		exit
	end

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
	result = @db.prepare("SELECT * FROM image WHERE id NOT IN(SELECT image_id FROM hit)").execute

	i = 0
	finished = 0
	result.each do |row|
		i += 1
		createNewHIT('', row[0], row[1], row[2], row[5])
	end
	
	####### All other tasks #######
	
	#Check for consensus
	hits = @db.execute("SELECT hit_id FROM hit WHERE complete!=1")
	
	hits.each do |hit|
		hit = hit[0]
		image = @db.get_first_row("SELECT * FROM image WHERE id=(SELECT image_id FROM hit WHERE hit_id='#{hit}')")
		hitDetail = @mturk.getHIT(:HITId => hit)
		answers = getAnswers(hit, "Approved")
		
		if(answers.length > 0)
			#Handle quantity and class questions differently
			if(/<QuestionIdentifier>[0-9]*[Q|q]<\/QuestionIdentifier>/ =~ answers[0][:Answer])#Quantity question
				if(answers.length == hitDetail[:MaxAssignments].to_i)#All questions must be answered for quantity
					#get average quantity estimate
					avg = 0
					answers.each do |answer|
						avg += /<FreeText>([0-9.]*)<\/FreeText>/.match(answer[:Answer])[1].to_f
					end
					avg /= answers.length
					
					question = /<QuestionIdentifier>([0-9]*)[Q|q]<\/QuestionIdentifier>/.match(answers[0][:Answer])[1]
					begin
						@db.execute("INSERT INTO food VALUES('#{image[0]}', '#{question}', '#{avg}')")#store answer in DB for easy retrieval
					rescue
						puts "Duplicate food identifier detected. You done screwed up."
					end
					@db.execute("UPDATE hit SET complete=1 WHERE hit_id='#{hit}'")
					finished += 1
				end
			else#Class question
				consensus = Hash.new
				answers.each do |a|
					@mturk.simplifyAnswer(a[:Answer]).each do |key, row|
						if(!row.kind_of?(Array))#stupid formatting stuff again
							row = [row]
						end
						row.each do |actualAnswer|
							if(consensus.has_key?(actualAnswer.to_s))
								consensus[actualAnswer.to_s] += 1
							else
								consensus[actualAnswer.to_s] = 1
							end
						end
						
						
					end
				end
				
				#do we have a majority vote yet? check for majority vote in every category
				majority = true
				consensus.each do |key, c|
					if(consensus[key] <= hitDetail[:MaxAssignments].to_f/2)
						majority = false
					end
				end
				
				#Gen new hits if we have majority or if all questions have been answered
				if(majority || answers.length == hitDetail[:MaxAssignments].to_i)
				
					decided = false#Have the masses decided what this is yet?
					if(majority)#quit early if we already have a majority vote, and approve all pending responses
						answers = @mturk.getAssignmentsForHIT(:HITId => hit)
						if(answers[:NumResults] > 0)
							if(answers[:NumResults] == 1)#fix inconsistent formatting
								answers[:Assignment] = [answers[:Assignment]]
							end
							#validate each response in hit
							answers[:Assignment].each do |assign|
								if(assign[:AssignmentStatus]=='Submitted')
									@mturk.approveAssignment(:AssignmentId => assign[:AssignmentId], :RequesterFeedback => "Thanks!")#Approve
								end
							end
						end
						@mturk.forceExpireHIT(:HITId => hit)
					end
					
					#generate new hits
					consensus.each do |key, c|
						if(c > hitDetail[:MaxAssignments].to_i/2)
							decided = true
							i+=1
							createNewHIT(key,image[0],image[1],getHITScalingParam(image[2],image[3],image[4],key.to_s.length),getHITScalingParam(image[5], image[6], image[7], key.to_s.length).to_i)
						end
					end
					
					#go up a tier and ask for quantity if no consensus was reached
					if(!decided)
						newQ = consensus.keys[0]
						newQ = newQ.to_s[0,newQ[0].to_s.length-1]+"Q"
						if(newQ.to_s.length > 1)
							i+=1
							createNewHIT(newQ,image[0],image[1],getHITScalingParam(image[2],image[3],image[4],newQ.to_s.length),getHITScalingParam(image[5], image[6], image[7], newQ.to_s.length).to_i)
						end
					end
					
					@db.execute("UPDATE hit SET complete=1 WHERE hit_id='#{hit}'")
				end
			end
		end
	end
	
	puts "     Created #{i} hits"
	puts "     Finished #{finished} hits"
end

#calculate HIT price, or number of assignments for HIT
def getHITScalingParam(min, max, step, taskTier)
	if(min > max || min+(step*(taskTier)) < max)
		return min+(step*(taskTier))
	else
		return max
	end
end

def autoUpdate
	processReviewableHits
	genTasks
end

def getWorkerResponses
	hits = getHITs
	workers = Hash.new
	hits.each do |hit|
		answers = getAnswers(hit, "Approved")
		answers.each do |a|
			@mturk.simplifyAnswer(a[:Answer]).each do |key, row|
				if(!row.kind_of?(Array))#stupid formatting stuff again
					row = [row]
				end
				index = ""
				row.each do |actualAnswer|
					if(index=="")
						index = actualAnswer.to_s
					else
						index = index +","+actualAnswer.to_s
					end
				end
				
				if(workers.has_key?(a[:WorkerId]))
					workers[a[:WorkerId]] << index
				else
					workers[a[:WorkerId]] = Array.new
					workers[a[:WorkerId]] << index
				end
			end
		end
	end
	return workers
end

################ Main ################

case ARGV[0]
	when "getHITs"
		puts getHITs
	when "getHIT"
		begin
			puts getHIT(ARGV[1])
		rescue
			puts "Not enough arguments"
		end
	when "getWorkerResponses"
		puts getWorkerResponses
	when "test"
		puts ""
	else
		autoUpdate
end
			