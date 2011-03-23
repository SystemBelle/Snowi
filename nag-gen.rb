#!/usr/bin/ruby

# Copyright 2010 Jamie Carranza
# jamie.carranza@gmail.com
# October 24, 2010

# nag-gen.rb

# Ruby script to parse the status.dat file produced by Nagios and output HAML

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

#    This file is part of Snowi.

#    Snowi is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    Foobar is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Snowi.  If not, see <http://www.gnu.org/licenses/>.

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

require 'rubygems'
require 'parseconfig'
require 'uri'

# Nagios status file
Status_file = '/usr/local/nagios/var/status.dat'

# Temp file
Temp_file = '/dev/shm/nagios-mobile.tmp'

class Datum < Struct.new(:last_command_check, :current_state, :last_hard_state, :active_checks_enabled, :last_check, :host_name, \
	:service_description, :plugin_output, :acked, :scheduled_downtime_depth)
end

# read status.dat and split into an array of strings which correspond to discrete status items
datum = open(Status_file) { |f| f.readlines('}') }

host_sched_down = Array.new

# Iterate over eatch datum string
datum.each do |d|

	# determine type of datum while still a string, ParseConfig can't do it
	$s = "#{d}"
	if
	    $s.include?('info')
	        @datum_type = 'info'
	    elsif $s.include?('programstatus')
	        @datum_type = 'programstatus'
	    elsif $s.include?('hoststatus')
	        @datum_type = 'hoststatus'
	    elsif $s.include?('servicestatus')
	        @datum_type = 'servicestatus'		# Could this be DRY'd?
	    elsif $s.include?('contactstatus')
	        @datum_type = 'contactstatus'
	    elsif $s.include?('servicecomment')
	        @datum_type = 'servicecomment'
	    elsif $s.include?('servicedowntime')
	        @datum_type = 'servicedowntime'
	end

	# write 'datum' string into tempfile so ParseConfig can read it
	File.open(Temp_file, 'w') {|f| f.write("#{d}") }

	# parse 'datum' tempfile config into a hash
	config = ParseConfig.new( Temp_file )

	if @datum_type == 'programstatus'
		# Not creating a Datum object for his datum type, why?
		@last_command_check = config.get_value('last_command_check')

		# Get system time
		@civiltime = Time.now.strftime("%m/%d/%Y %I:%M %p")

		# Get last Nagios update time
		@last_command_check_int = Time.at(@last_command_check.to_i)
		@last_command_check_stamp = @last_command_check_int.strftime("%m/%d/%Y %I:%M %p")

		puts "<center><img src=\"/logo.jpg\"></center>"
		puts "<b>System Time:</b> #{@civiltime}<br />"
		puts "<b>Last Command Check:</b> #{@last_command_check_stamp}<br /><br />"
	end

	if @datum_type == 'hoststatus'
		@current_state = config.get_value('current_state')
		@active_checks_enabled = config.get_value('active_checks_enabled')
		@last_check = config.get_value('last_check')
		@host_name = config.get_value('host_name')
		@plugin_output = config.get_value('plugin_output')
		@scheduled_downtime_depth = config.get_value('scheduled_downtime_depth')

				# --> I created a Datum object for this datum type, is there any point?
		# Create a Datum object using the value of the @hn variable as a name
		# and then setting the value of the @host_name variable, which in this case is also the value of @hn
		@each = Datum.new("", @current_state, @last_hard_state, @active_checks_enabled, @last_check, @host_name, "", \
		@plugin_output, @acked, @scheduled_downtime_depth)

		@civiltime = Time.at(@last_check.to_i) # convert UNIX to civil time
		@timestamp = @civiltime.strftime("%m/%d/%Y %I:%M %p")

		# Create an array containing hostnames in sched. downtime
		if @each.scheduled_downtime_depth != '0'
			host_sched_down << @host_name
		end


		if @current_state != '0' && @active_checks_enabled == '1'
			puts "%hr"
			puts "<b>#{@each.host_name}</b><br />"
			puts "#{@timestamp}<br />"
			puts "#{@each.plugin_output}<br />"
		end
	end

	if @datum_type == 'servicestatus'
		@current_state = config.get_value('current_state')
		@last_hard_state = config.get_value('last_hard_state')
		@active_checks_enabled = config.get_value('active_checks_enabled')
		@last_check = config.get_value('last_check')
		@host_name = config.get_value('host_name')
		@service_description = config.get_value('service_description')
		@plugin_output = config.get_value('plugin_output')
		@acked = config.get_value('problem_has_been_acknowledged')

		@each = Datum.new("", @current_state, @last_hard_state, @active_checks_enabled, @last_check, @host_name, @service_description, \
		@plugin_output, @acked, "")

		@civiltime = Time.at(@last_check.to_i) # convert UNIX to civil time
		@timestamp = @civiltime.strftime("%m/%d/%Y %I:%M %p")

		if @each.acked == '0'
			@ack_status = '<b>Not Acknowledged</b>'
			@url = "/ack_svc_prob/#{@each.host_name}/#{@each.service_description}/"
			@ack_color = 'not_acked'
		elsif @each.acked == '1'
			@ack_status = '<b>Acknowledged</b>'
			@svc = URI::escape(@each.service_description)
			@url = "/rem_svc_ack/#{@each.host_name}/#{@svc}"
			@ack_color = 'acked'
		end

		if !host_sched_down.include?(@each.host_name)
			if @last_hard_state != '0' && @active_checks_enabled == '1'
				puts "%hr"
				puts "<b>#{@each.host_name}</b><br />"
                puts "#{@timestamp}<br />"
				puts "#{@each.service_description} - <a href=\"#{@url}\" class=\"#{@ack_color}\">#{@ack_status}</a><br />"
				puts "#{@each.plugin_output}<br />"
			end
		end

	end
end # END datum.each

