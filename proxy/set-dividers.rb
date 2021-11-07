#!/usr/bin/env ruby

require 'json'

first, last = *ARGV
start = false
JSON.parse(open('sets.json', &:read))['data'].each do |set|
  next unless start or set['ptcgoCode'] == first
  start = true

  puts "\\divider{#{set['ptcgoCode']} #{set['name']}" +
    " \\includegraphics[height=.8\\baselineskip]" +
    "{set-logos/#{set['id']}.png}}"
  break if set['ptcgoCode'] == last
end




