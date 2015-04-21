#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'mturk'

@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Sandbox

# Use this line instead if you want the production website.
#@mturk = Amazon::WebServices::MechanicalTurkRequester.new :Host => :Production


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

################ Main ################
processReviewableHits()
#earlyExpire()

#puts @mturk.getReviewableHITs(:status => "Unassignable")