#!/usr/bin/ruby
# Author: Derek Downey
# sys_schema_statements.rb - Grab statements from performance schema to be grok'd/filtered by logstash
# Current version relies on sys_schema from Mark Leith

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'optparse'
require 'mysql2'
require 'inifile'
require 'json'

# Performance schema should be enabled, and the events_statements_* consumers as well. An example my.cnf:
# [mysqld]
# *snip*
# performance_schema=ON
# performance_schema_consumer_events_statements_history=ON
# performance_schema-consumer_events_statements_history_long=ON
# *snip
#
# Or at runtime if performance_schema is enabled:
#  UPDATE performance_schema.setup_consumers SET ENABLED='YES' WHERE NAME LIKE 'events_statements_%';


options = {:ini => nil}

parser = OptionParser.new do|opts|
  opts.banner = "Usage: sys_schema_statements.rb [options]"
  opts.on('-i', '--ini inifile', 'inifile') do |inifile|
    options[:ini] = inifile;
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

parser.parse!

if options[:ini]
  ini = IniFile.load(options[:ini])
  section = ini['client']
  db_user = section['user']
  db_pass = section['password']
  socket = section['socket']
else
  db_user = "root"
  db_pass = ""
  socket = ""
end

client = Mysql2::Client.new(:host => "localhost", :username => db_user, :password => db_pass, :socket => socket)
results = client.query("SELECT *,CONCAT(DATE_FORMAT(DATE_SUB(NOW(),INTERVAL (SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE variable_name='UPTIME')-TIMER_START*10e-13 second),'%Y-%m-%d %T')) start_time, timer_wait/10E-8 wait_ms FROM performance_schema.events_statements_history_long;")
client.query("TRUNCATE TABLE performance_schema.events_statements_history_long")
results.each do |row|
   puts row.to_json
end
client.close();