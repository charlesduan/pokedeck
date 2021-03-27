#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'net/http'
require 'ostruct'
require 'open-uri'

class PokemonTcgApi

  def initialize(options)
    @key = open("api-key.txt") { |io| io.read.chomp }
    @options = options
  end

  def make_dir(dir)
    Dir.mkdir(dir) unless File.directory?(dir)
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

  def sets
    return @sets if @sets
    begin
      @sets = open(@options.sets_file) do |io| JSON.parse(io.read) end["data"]
      return @sets
    rescue Errno::ENOENT
      raise "Sets not cached; run command \"sets\""
    end
  end

  ENERGY_IDS = {
    1 => 'sm1-164', # Grass
    2 => 'sm1-165', # Fire
    3 => 'sm1-166', # Water
    4 => 'sm1-167', # Lightning
    5 => 'sm1-168', # Psychic
    6 => 'sm1-169', # Fighting
    7 => 'sm1-170', # Darkness
    8 => 'sm1-171', # Metal
    9 => 'sm1-172', # Fairy
  }

  #
  # Retrieves the API card ID given a PTCGO identifier of expansion code and
  # card number.
  #
  def card_id(expansion_code, number)

    case expansion_code

    when 'SHF'
      # Special case because Shining Fates has two number series so code SHF
      # shows up twice in the sets database
      return "swsh45sv-#{number}" if number.start_with?("SV")
      return "swsh45-#{number}"

    when 'Energy'
      return ENERGY_IDS[number.to_i]
    end

    expansion_code = {
      'SSP' => 'PR-SW',
      'SMP' => 'PR-SM',
    }[expansion_code] || expansion_code

    set = sets.find { |s| s["ptcgoCode"] == expansion_code }
    raise "Unknown set #{expansion_code}" unless set
    return "#{set["id"]}-#{number}"
  end

  #
  # Retrieves the card data from the API or the cache.
  #
  def card_data(expansion, number)
    id = card_id(expansion, number)
    make_dir(@options.card_dir)
    filename = File.join(@options.card_dir, "#{expansion}-#{number}.json")
    if File.exist?(filename)
      return File.open(filename) do |io| JSON.parse(io.read) end
    else
      card_data = request("cards/#{id}")["data"]
      open(filename, "w") do |io|
        io.write(JSON.pretty_generate(card_data))
      end
      return card_data
    end
  end


end

#
# Constructs the TeX file for the proxy cards.
#
class TeXCardBuilder
  def initialize(options)
    @options = options
    @api = @options.api

    #
    # Keeps count of the cards added to this print.
    #
    @card_count = 0
    @cards = {
      'Pokémon' => {},
      'Trainer' => {},
      'Energy' => {},
    }

    #
    # Buffer of text to add to the document after the preamble.
    #
    @buffer = ""

    @name = "[New Deck]"
    @description = "[Description goes here]"
  end

  attr_accessor :name, :description

  def add_card(quantity, expansion, number)
    data = @api.card_data(expansion, number)

    @card_count += quantity

    if @cards[data['supertype']][data]
      @cards[data['supertype']][data] += quantity
    else
      @cards[data['supertype']][data] = quantity
    end

    return if @options.no_cards
    quantity.times do
      case data['supertype']
      when 'Pokémon' then add_pokemon(data)
      when 'Trainer' then add_trainer(data)
      when 'Energy' then add_energy(data)
      end
    end
  end

  TYPE_CODES = {
    'Grass' => 'G',
    'Fire' => 'R',
    'Water' => 'W',
    'Lightning' => 'L',
    'Psychic' => 'P',
    'Fighting' => 'F',
    'Darkness' => 'D',
    'Metal' => 'M',
    'Fairy' => 'F',
    'Dragon' => 'N',
    'Colorless' => 'C',
  }

  def encode_types(array)
    array.map { |x| TYPE_CODES[x] }.join("")
  end

  def encode_wr(array)
    res = ""
    if array
      array.each do |hash|
        res << "\\do{#{TYPE_CODES[hash['type']]}}{#{hash['value']}}"
      end
    end
    return res
  end

  def text(str)
    if str && str.length > 40
      "%\n#{str}%\n"
    else
      "#{str}"
    end
  end

  def get_picture(data)
    outfile = File.join(@options.image_dir, data['id'] + ".jpg")
    return outfile if File.exist?(outfile)
    URI.open(data['images']['large']) do |io|
      cmd = [ 'convert', '-', '-crop', '620x385+57+98', outfile ]
      puts cmd.join(" ")
      IO.popen(cmd, 'w') do |pio|
        pio.write(io.read)
      end
    end
    return outfile
  end

  def add_pokemon(data)
    @buffer << "\\pokemoncard{%\n"
    @buffer << "\\nameline{#{data['subtypes'][0]}}{#{data['name']}}" \
      "{#{data['hp']}}{#{encode_types(data['types'])}}\n"

    evolve = "#{data['evolvesFrom']}" if data['evolvesFrom']
    subtypes = data['subtypes'][1..-1].reject { |x| data['name'].include?(x) }
    subtypes = subtypes.map { |x| "\\do{#{x}}" }.join
    if evolve || !subtypes.empty?
      @buffer << "\\subtitleline{#{evolve}}{#{subtypes}}\n"
    end

    @buffer << "\\imageline{#{get_picture(data)}}\n"

    if data['abilities']
      data['abilities'].each do |ability|
        @buffer << "\\ability{#{ability['type']}}{#{ability['name']}}" \
          "{#{text(ability['text'])}}\n"
      end
    end

    if data['attacks']
      data['attacks'].each do |attack|
        @buffer << "\\attack{#{encode_types(attack['cost'])}}" \
          "{#{attack['name']}}" \
          "{#{attack['damage']}}{#{text(attack['text'])}}\n"
      end
    end

    @buffer << "\\wrrline{#{encode_wr(data['weaknesses'])}}" \
      "{#{encode_wr(data['resistances'])}}" \
      "{#{encode_types(data['retreatCost'])}}\n"

    if data['rules']
      data['rules'].each do |rule|
        @buffer << "\\ruleline{#{text(rule)}}\n"
      end
    end

    @buffer << "\\cardid{#{data['set']['ptcgoCode']}}{#{data['number']}}\n"
    @buffer << "}\n"
  end

  def add_trainer(data)
  end


  def add_energy(data)
  end

  def add_summary
    if @card_count != 60
      warn("Expected 60 cards, but deck has #@card_count")
    end

    @buffer << "\\summarycard{#@name}{#@description}{%\n"
    @cards.each do |type, list|
      @buffer << "\\summaryhead{#{type}}\n"
      list.each do |data, quantity|
        name = data['name'].gsub(/\(.*\)/, '')

        @buffer << "\\summaryline{#{quantity}}{#{name}}"
        if data['supertype'] == 'Energy' && data['subtypes'].include?('Basic')
          @buffer << "{}{}\n"
        else
          @buffer << "{#{data['set']['ptcgoCode']}}{#{data['number']}}\n"
        end
      end
    end
    @buffer << "}\n"
  end

  def write_file(io)
    #open(File.join(@options.templates_dir, @options.tex_preamble)) do |pio|
    #  io.write(pio.read)
    #end
    io.write(
      "\\input{#{File.join(@options.templates_dir, @options.tex_preamble)}}\n"
    )
    io.write(@buffer)
    io.write("\\end{document}\n")
  end
end



class Executor

  def initialize(options)
    @api = PokemonTcgApi.new(options)
    options.api = @api
    @texer = TeXCardBuilder.new(options)
    @options = options
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
    @api.make_dir(@options.set_logo_dir)

    @api.sets.each do |set|
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
    data = @api.card_data(expansion, number)
    p data
  end

  def doc_deck ; "Produce a proxy deck sheet" end
  def cmd_deck(file = nil)
    if file
      open(file) do |io| read_deck(io) end
    else
      read_deck(STDIN)
    end
    @texer.add_summary
    open(@options.tex_output, 'w') do |io|
      @texer.write_file(io)
    end
  end
  def read_deck(io)
    io.each do |line|
      if line =~ /^(\d+)\s(?:.*\s)?(\w+)\s+(\w+)\s*$/
        @texer.add_card($1.to_i, $2, $3)
      else
        warn("Could not parse line: #{line}")
      end
    end
  end
end

options = OpenStruct.new(
  :sets_file => "sets.json",
  :set_logo_dir => "set-logos",
  :card_dir => "cards",
  :image_dir => "images",
  :templates_dir => "tex_templates",
  :tex_preamble => "preamble.tex",
  :tex_output => "deck.tex",
)
Executor.new(options).run(*ARGV)

