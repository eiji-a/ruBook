#!/usr/bin/ruby
#
# ebookman:
#
# AUTHOR : E.Akagi
# CREATED: 2011.05.24.
#

require 'fileutils'

# CONSTANTS
INTERVAL = 10
HOME = '/Users/eiji'
SOURCE = HOME + '/Documents/My Kindle Content/ebookman'
TARGET = '/Volumes/Kindle/documents/ebookman'
TOPDF = HOME + '/project/ebookman/topdf.rb'
KINDLEDIR = SOURCE + '/kindle'

def init
  @connected = false
  @synced = false
end

def connect?
  if File.exist?(TARGET)
    return false if @synced
    @connected = true
    puts "Connected!"
    true
  else
    if @connected
      @connected = false
      @synced = false
      puts "Disconnected!"
    end
    false
  end
end

def read_target
  @target = {}
  Dir.foreach(TARGET) do |f|
    next if f =~ /^\./
    puts "TARGET: #{f}"
    @target[f] = true
  end
end

def delete_discarded
  @target.each do |k, v|
    next if v == false
    next if File.extname(k) != '.pdf'
    puts "DELETE: #{k}"
  end
end

def create_pdf(f, fn)
  puts "#{TOPDF} -o '#{KINDLEDIR}/#{fn}' '#{SOURCE}/#{f}'"
  system "#{TOPDF} -o '#{KINDLEDIR}/#{fn}' '#{SOURCE}/#{f}'"
  raise StandardError, "can't create #{fn}" if !File.exist?(KINDLEDIR + '/' + fn)
end

def sync_pdf(f)
  if @target[f] != nil
    @target[f] = false
    return
  end
  FileUtils.copy_file(SOURCE + '/' + f, TARGET + '/' + f)
  puts "SYNC: #{f}"
end

def sync_zip(f)
  fn = File.basename(f, '.zip') + '.pdf'
  puts "FILENAME: #{fn}"
  create_pdf(f, fn) if File.exist?(KINDLEDIR + '/' + fn) == false
  if @target[fn] != nil
    @target[fn] = false
    return 
  end
  FileUtils.copy_file(KINDLEDIR + '/' + fn, TARGET + '/' + fn)
  puts "SYNC: #{fn}"
end

def sync
  puts "Syncing ... "
  read_target
  Dir.foreach(SOURCE) do |f|
    case File.extname(f)
    when /^\.pdf$/i
      sync_pdf(f)
    when /^\.zip$/i
      puts "ZIP: #{f}"
      sync_zip(f)
    else
    end
  end
  delete_discarded
  @synced = true
  puts "done!"
end

def main
  init
  while true
    sync if connect?
    sleep INTERVAL
  end  
end

main
