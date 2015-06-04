#!/usr/bin/ruby
# Author: Derek Downey
# performance_schema_statements.rb - Grab statements from performance schema to be grok'd/filtered by logstash

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
  opts.banner = "Usage: performance_schema_statements.rb [options]"
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

client = Mysql2::Client.new(:username => db_user, :password => db_pass, :socket => socket)
results = client.query("SELECT
  THREAD_ID, EVENT_ID, EVENT_NAME AS STATEMENTS_EVENT_NAME, DIGEST, DIGEST_TEXT,
  TIMER_WAIT, CURRENT_SCHEMA, OBJECT_SCHEMA, OBJECT_TYPE, OBJECT_NAME, MYSQL_ERRNO,
  RETURNED_SQLSTATE, LOCK_TIME,
  ERRORS, WARNINGS, ROWS_AFFECTED, ROWS_SENT, ROWS_EXAMINED, CREATED_TMP_DISK_TABLES,
  CREATED_TMP_TABLES, SELECT_FULL_JOIN, SELECT_FULL_RANGE_JOIN, SELECT_RANGE, SELECT_RANGE_CHECK,
  SELECT_SCAN, SORT_MERGE_PASSES, SORT_RANGE, SORT_ROWS, SORT_SCAN, NO_INDEX_USED, NO_GOOD_INDEX_USED
FROM performance_schema.events_statements_history_long AS history
WHERE DATE_FORMAT(DATE_SUB(NOW(),INTERVAL (SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE variable_name='UPTIME')-TIMER_START*10e-13 second),'%Y-%m-%d %T') >= DATE_SUB(NOW(), INTERVAL 10 SECOND);")
results.each do |row|
   puts row.to_json
end

results = client.query("SELECT
  THREAD_ID, EVENT_ID, EVENT_NAME AS WAITS_EVENT_NAME, TIMER_WAIT, SPINS,
  OBJECT_SCHEMA, OBJECT_NAME, INDEX_NAME,
  OBJECT_TYPE, OPERATION, NUMBER_OF_BYTES
FROM performance_schema.events_waits_history_long
WHERE DATE_FORMAT(DATE_SUB(NOW(),INTERVAL (SELECT VARIABLE_VALUE FROM information_schema.global_status WHERE variable_name='UPTIME')-TIMER_START*10e-13 second),'%Y-%m-%d %T') >= DATE_SUB(NOW(), INTERVAL 10 SECOND);")
results.each do |row|
   puts row.to_json
end
client.close;
