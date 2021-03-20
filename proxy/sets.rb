#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'net/http'
require 'ostruct'
require 'open-uri'

class PokemonTcgApi

  def initialize
    @key = open("api-key.txt") { |io| io.read.chomp }
  end

  def request(endpoint, params = {})
    uri = URI("https://api.pokemontcg.io/v2/#{endpoint}/")
    uri.query = URI.encode_www_form(params) unless params.empty?
    req = Net::HTTP::Get.new(uri)
    req['X-Api-Key'] = "#{@api_token}"
    
    http = Net::HTTP.new(req.uri.host, req.uri.port)
    http.use_ssl = true
    res = http.start { |http| http.request(req) }
    case res
    when Net::HTTPSuccess
      return JSON.parse(res.body)
    else
      raise "HTTP error: #{res.class}"
    end
  end

end

class TeXCardBuilder
  def initialize(card_data)
  end
end



class Executor

  def initialize
    @api = PokemonTcgApi.new
    @options = OpenStruct.new(
      :sets_file => "sets.json",
      :set_logo_dir => "set-logos",
      :card_dir => "cards",
    )
  end

  def make_dir(dir)
    Dir.mkdir(dir) unless File.directory?(dir)
  end

  def load_sets
    return if @sets
    @sets = open(@options.sets_file) do |io| JSON.parse(io.read) end["data"]
  end

  def card_id(expansion_code, number)

    # Special case because Shining Fates has two number series so code SHF shows
    # up twice in the sets database
    if expansion_code == 'SHF'
      return "swsh45sv-#{number}" if number.start_with?("SV")
      return "swsh45-#{number}"
    end

    expansion_code = {
      'SSP' => 'PR-SW',
      'SMP' => 'PR-SM',
    }[expansion_code] || expansion_code

    load_sets
    set = @sets.find { |s| s["ptcgoCode"] == expansion_code }
    raise "Unknown set #{expansion_code}" unless set
    return "#{set["id"]}-#{number}"
  end

  def run(cmd, *params)
    send("cmd_#{cmd}", *params)
  end

  def doc_sets ; "Retrieve data on all expansion sets" end
  def cmd_sets
    sets = @api.request("sets")
    open(@options.sets_file, "w") do |io|
      io.write(JSON.pretty_generate(sets))
    end
  end

  def doc_set_logos ; "Download logos for all expansion sets" end
  def cmd_set_logos
    load_sets
    make_dir(@options.set_logo_dir)

    @sets.each do |set|
      url = set["images"]["symbol"]
      name = set["id"]

      URI.open(url) do |io|
        open(File.join(@options.set_logo_dir, "#{name}.png"), 'w') do |wio|
          wio.write(io.read)
        end
      end

    end
  end

  def doc_card ; "Download card data" end
  def cmd_card(expansion, number)
    id = card_id(expansion, number)
    card_data = @api.request("cards/#{id}")["data"]

    make_dir(@options.card_dir)
    open(File.join(@options.card_dir, "#{id}.json"), "w") do |io|
      io.write(JSON.pretty_generate(card_data))
    end
  end

end

Executor.new.run(*ARGV)

