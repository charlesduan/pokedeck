#!/usr/bin/ruby

def name(series, num)
  "#{series}_#{num}_H_EN.png"
end

def url(series, num)
  "https://limitlesstcg.nyc3.digitaloceanspaces.com/tpci/" +
    "#{series}/#{name(series, num)}"
end

ENERGY = {
  1 => %w(SUM G), # Grass
  2 => %w(SUM R), # Fire
  3 => %w(SUM W), # Water
  4 => %w(SUM L), # Lightning
  5 => %w(SUM P), # Psychic
  6 => %w(SUM F), # Fighting
  7 => %w(SUM D), # Darkness
  8 => %w(SUM M), # Metal
  9 => %w(SUM Y), # Fairy
}

def process_line(text, io)
  return if text =~ /^#/
  if text =~ /^(\d+)\s(?:.*\s)?(\w+)\s+(\d+)\s*$/
    count, series, num = $1, $2, $3

    if series == 'Energy'
      series, num = ENERGY[num.to_i]
    else
      num = "%03d" % num
    end

    filename = File.join("cache", name(series, num))
    unless File.exist?(filename)
      system('curl', '-o', filename, url(series, num))
    end
    count.to_i.times do
      io.puts("\\usecard{#{filename}}")
    end
  else
    warn("Could not parse line: #{text}")
  end
end

open("sheet.tex", "w") do |io|
  io.write(<<-EOF)
\\documentclass[12pt]{article}

\\usepackage{geometry}
\\geometry{height=10.5in,width=7.5in}
\\usepackage{graphicx}
\\def\\usecard#1{\\includegraphics[width=6.3cm]{#1}\\kern0.5pt\\allowbreak\\ignorespaces}

\\begin{document}

\\parindent=0pt
\\baselineskip=0pt
\\lineskip=0.5pt
\\raggedright

  EOF

  ARGF.each do |line|
    process_line(line, io)
  end

  io.puts("\\end{document}")

end

system("xelatex", "sheet")

system("open", "sheet.pdf")

