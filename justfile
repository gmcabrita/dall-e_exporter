set shell := ["powershell.exe", "-c"]
set dotenv-load

default: deps run

# install dependencies
deps:
  bundle install

# run the DALL-E exporter
run:
  ruby bin/exporter

# open a REPL
console:
  ruby bin/console
