# snowi.rb
# Copyright 2011 Jamie Carranza
# jamie.carranza@gmail.com
# March 22, 2011

# Snowi is a simple Ruby/Sinatra based Nagios web interface suitable for mobile devices.  It's sort of a clone
# of Nag Small Screen by Ryan McDonald.

	# Alerts can be acknowledged or un-acknowledged using Nagios' 'external commands' feature.
	# If logged in using HTTP authentication methods, the user available in the HTTP_X_REMOTE_USER variable is noted as
	# the acknowledging party.

	# Parses the 'status.dat' file produced by Nagios
	# The defaults are fine for many installations and correspond with the defaults you get with Nagios
	# Snowi requires Ruby 1.8 and the following gems: sinatra, haml, parseconfig
	# Have the main HTTP server act as reverse proxy for the port/socket this server listens on

# --> This script requires a companion script called nag-gen.rb to generate page content.

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
require 'sinatra'
require 'haml'
require 'sass'

# Port, don't use the port your main Nagios interface is on
# set :port, 4567

# Where Nagios Mobile lives
Docroot = '/usr/local/nagios/snowi/'

# Acknowledgement stickiness
Sticky = '0'

# Whether to send a notification when acked
Notify = '1'

# Page Title
Title = 'Snowi'

# Nagios external command pipe
CommandFile = '/usr/local/nagios/var/rw/nagios.cmd'

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
content = Docroot + 'body.haml'

# Set the 'public' directory to the app root
set :public, File.dirname(__FILE__) + '/'

# Styles
get '/styles.css' do
  content_type 'text/css'
  response['Expires'] = (Time.now + 86400).httpdate
  sass :style
end

# Main Page
get '/' do
	@c = %x{"#{Docroot}/nag-gen.rb"}
	File.open(content, 'w') {|f| f.write("#{@c}") }
    body_template  = File.read( content )
    body_haml_engine = Haml::Engine.new(body_template)
    @body = body_haml_engine.render
    haml :page
end

# Acknowledge service problem
get '/ack_svc_prob/:host/:service/?' do |host, service|
	@svc_desc = URI::unescape("#{service}")
	@now = Time.now.to_i
	@user = request.env["HTTP_X_REMOTE_USER"].to_s
	@string = "[#{@now}] ACKNOWLEDGE_SVC_PROBLEM;#{host};#{service};#{Sticky};#{Notify};#{p};#{@user};Nagios Mobile"
	File.open(CommandFile, 'a') {|f| f.puts(@string) }
	redirect '/wait'
end

# Remove service acknowledgment
get '/rem_svc_ack/:host/:service/?' do |host, service|
	@svc_desc = URI::unescape("#{service}")
	@now = Time.now.to_i
	@string = "[#{@now}] REMOVE_SVC_ACKNOWLEDGEMENT;#{host};#{@svc_desc}"
	File.open(CommandFile, 'a') {|f| f.puts(@string) }
	'Sending Command...'
	redirect '/wait'
end

# Wait for command and redirect to '/'
get '/wait' do
	haml :wait
end

__END__

@@ page
!!!
%html
	%head
		%title
			= Title
		%meta{ 'charset' => 'utf-8' }
		%meta{ :name => 'description', :content => 'Simple Nagios Interface' }
		%meta{ "http-equiv" => "refresh", :content => '190' }
		%link{ :href => '/styles.css', :rel => 'stylesheet', :type => 'text/css' }
		%link{ :href=> '/favicon.ico', :rel => 'shortcut icon' }
	%body
		= @body


@@ style
body
	background-color: black
	font-family: Verdana, Arial, Helvetica
	font-size: 10px
	color: white

.acked
	color: #00FF00

.not_acked
	color: #FF4040


@@ wait
!!!
%html
	%head
		%title
			= Title
		%link{ :href => '/styles.css', :rel => 'stylesheet', :type => 'text/css' }
		%meta{ 'http-equiv' => 'refresh', :content => "2;url=#{request.url.gsub(/wait/, '')}" }
	%body Sending Command...

