# Pokemon Proxy Deck Builder

This script takes a list of Pokemon cards and produces a LaTeX file that
compiles to a sheet of those cards. Decks should follow the syntax of
pokegoldfish.com:

  [num-cards] [name] [series] [card-num]

where *num-cards* is the number of the cards used in the deck, *series* is the
three-letter abbreviation of the expansion, and *card-num* is the number of the
card in that series. Energy cards use the series "Energy" with *card-num*
corresponding to the table in the script.
