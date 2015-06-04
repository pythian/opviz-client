#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# Linux network interface metrics
# ====
#
# Simple plugin that fetchs metrics from all interfaces
# on the box using the /sys/class interface.
#
# Use the data with graphite's `nonNegativeDerivative()` function
# to construct per-second graphs for your hosts.
#
# Loopback iface (`lo`) is ignored.
#
# Compat
# ------
#
# This plugin uses the `/sys/class/net/<iface>/statistics/{rx,tx}_*`
# files to fetch stats. On older linux boxes without /sys, this same
# info can be fetched from /proc/net/dev but additional parsing
# will be required.
#
# Example:
# --------
#
# $ ./metrics-packets.rb --scheme servers.web01
#   servers.web01.eth0.tx_packets 982965    1351112745
#   servers.web01.eth0.rx_packets 1180186   1351112745
#   servers.web01.eth1.tx_packets 273936669 1351112745
#   servers.web01.eth1.rx_packets 563787422 1351112745
#
# Copyright 2012 Joe Miller <https://github.com/joemiller>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

TCP_STATES = {
  '00' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  'FF' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  '01' => 'ESTABLISHED',
  '02' => 'SYN_SENT',
  '03' => 'SYN_RECV',
  '04' => 'FIN_WAIT1',
  '05' => 'FIN_WAIT2',
  '06' => 'TIME_WAIT',
  '07' => 'CLOSE',
  '08' => 'CLOSE_WAIT',
  '09' => 'LAST_ACK',
  '0A' => 'LISTEN',
  '0B' => 'CLOSING'
}

class LinuxPacketMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.net"

  def netstat(protocol = 'tcp')
    state_counts = Hash.new(0)
    port_states = Hash.new(0)
    TCP_STATES.each_pair { |_hex, name| state_counts[name] = 0 }

    # #YELLOW
    File.open('/proc/net/' + protocol).each do |line| # rubocop:disable Style/Next
      line.strip!
      if m = line.match(/^\s*\d+:\s+(.{8}):(.{4})\s+(.{8}):(.{4})\s+(.{2})/) # rubocop:disable AssignmentInCondition
        connection_state = m[5]
        connection_port = m[2].to_i(16).to_s
        connection_state = TCP_STATES[connection_state]

        port_states.store(connection_port, state_counts.dup) unless port_states.has_key?(connection_port)
        port_states[connection_port][connection_state] += 1
      end
    end
    port_states
  end

  def run
    timestamp = Time.now.to_i

    Dir.glob('/sys/class/net/*').each do |iface_path|
      next if File.file?(iface_path)
      iface = File.basename(iface_path)
      next if iface == 'lo'

      tx_pkts = File.open(iface_path + '/statistics/tx_packets').read.strip
      rx_pkts = File.open(iface_path + '/statistics/rx_packets').read.strip
      tx_bytes = File.open(iface_path + '/statistics/tx_bytes').read.strip
      rx_bytes = File.open(iface_path + '/statistics/rx_bytes').read.strip
      tx_errors = File.open(iface_path + '/statistics/tx_errors').read.strip
      rx_errors = File.open(iface_path + '/statistics/rx_errors').read.strip
      begin
        if_speed = File.open(iface_path + '/speed').read.strip
      rescue
        if_speed = 0
      end
      output "#{config[:scheme]}.#{iface}.tx_packets", tx_pkts, timestamp
      output "#{config[:scheme]}.#{iface}.rx_packets", rx_pkts, timestamp
      output "#{config[:scheme]}.#{iface}.tx_bytes", tx_bytes, timestamp
      output "#{config[:scheme]}.#{iface}.rx_bytes", rx_bytes, timestamp
      output "#{config[:scheme]}.#{iface}.tx_errors", tx_errors, timestamp
      output "#{config[:scheme]}.#{iface}.rx_errors", rx_errors, timestamp
      output "#{config[:scheme]}.#{iface}.if_speed", if_speed, timestamp
    end

    # Collect statistics for connection types
    timestamp = Time.now.to_i
    netstat('tcp').each do |port, state_arr|
      state_arr.each do |state, count|
        # graphite_name = config[:port] ? "#{config[:scheme]}.states.#{config[:port]}.#{state}" :
        #   "#{config[:scheme]}.states.#{state}"
        graphite_name = "#{config[:scheme]}.states.#{port}.#{state}"
        output "#{graphite_name}", count, timestamp
      end
    end
    ok
  end
end