#!/usr/bin/ruby
# -*- coding: euc-jp -*-
#
#

require 'zlib'
require 'rubygems'
require 'zipruby'
require 'fileutils'
require 'yaml'
require 'pdf'
require 'getopts'

TMPDIR = '/tmp'
FILE = '/usr/bin/file'
SIPS = 'sips'
CONVERT = 'convert'

KINDLE3  = [560, 734, 'gray']
READERT1 = [584, 754, 'gray']
IPAD     = [768, 1008, 'full']

def read_device_config(cfile)
  param = {}
  begin
    if cfile == nil || cfile == ''
      raise StandardError, "config file isn't set"
    end
    File.open(cfile, 'r') do |fp|
      param = YAML::load(fp.read)
    end
    raise StandardError, "no enough parameters" if !param['width'] || !param['height']
  rescue StandardError => e
    STDERR.puts "READ DEVICE CONFIG: #{e.message}"
    exit(1)
  end
  $CONF['pagesize'] = [param['width'], param['height']]
  $CONF['aspect'] = param['height'].to_f / param['width'].to_f
  $CONF['color'] = param['color'] || 'gray'
end

def set_conf(dev)
  w = dev[0]
  h = dev[1]
  c = dev[2]
  $CONF = {
    'pagesize' => [w, h],
    'aspect'   => (h.to_f / w.to_f),
    'color'    => (c || 'gray')
  }
end

def select_device(device)
  case device
  when 'kindle3'
    set_conf(KINDLE3)
  when 'ipad'
    set_conf(IPAD)
  else
    set_conf(KINDLE3)
  end
end

def init
  unless getopts('', 'c:', 'o:')
    abort 'Usage: topdf.rb [-c device_config] [-o output_file] zip_file'
  end
=begin
  if ARGV.size == 0
    STDERR.puts 'Usage: topdf.rb [-c device_config] [-o output_file] zip_file'
    exit(1)
  end

  if ARGV[0] == '-c'
    ARGV.shift
    select_device(ARGV.shift)
    #read_device_config(ARGV.shift)
  else
    select_device('')
  end
=end

  if $OPT_c
    select_device($OPT_c)
  else
    select_device('')
  end

  zfile = ARGV.shift
  if zfile == nil || zfile == ''
    STDERR.puts "ERROR: Zip file isn't set"
    exit(1)
  end
  @zfile = zfile

  @title = File.basename(@zfile, '.zip')

  if $OPT_o
    @output = $OPT_o
  else
    @output = @title + '.pdf'
  end
  @output_fp = File.open(@output, 'w')

  #Dir.mkdir('tmp') unless File.directory?('tmp')
  #FileUtils.rm_rf(TMPDIR) if File.directory?(TMPDIR)
  #Dir.mkdir(TMPDIR)
  @tmp1 = TMPDIR + 'temp1.bmp'
  @tmp2 = TMPDIR + 'temp2.bmp'
  @tmp3 = TMPDIR + 'temp3.bmp'
  @tmp4 = TMPDIR + 'temp4.bmp'
  @tmp5 = TMPDIR + 'temp5.bmp'
end

def postproc
  @output_fp.close
  File.delete(@tmp1)
  File.delete(@tmp2)
  File.delete(@tmp3)
  File.delete(@tmp4)
  File.delete(@tmp5)
  FileUtils.rm(Dir.glob(TMPDIR + '/topdf_*.gif'))
  #FileUtils.rm_rf(TMPDIR)
end

def init_pdf(npage)
end

def pickup(arcfile)
  fn = TMPDIR + '/' + File.basename(arcfile.name)
  File.open(fn, 'w+b') do |fp|
    fp.print(arcfile.read)
  end
  ft = `#{FILE} #{fn}`
  if ft !~ /JPEG image/
    File.delete(fn)
    return nil
  end
  return fn
end

def get_size(file)
  size = `#{SIPS} -g pixelWidth -g pixelHeight #{file}`
  size =~ /pixelWidth: (\d+)\s+pixelHeight: (\d+)/
  xs = $1.to_f
  ys = $2.to_f
  if ys / xs >= $CONF['aspect']
    #縦長
    ysize = $CONF['pagesize'][1] - 2
    xsize = (xs * ysize / ys).to_i
  else
    #横長
    xsize = $CONF['pagesize'][0] - 2
    ysize = (ys * xsize / xs).to_i
  end
  return xsize, ysize
end

def convert(file, num)
  xsize, ysize = get_size(file)
  fnum = sprintf "%04d", num
  system "#{SIPS} -s format bmp '#{file}' --out #{@tmp1} > /dev/null"
  system "#{CONVERT} -geometry #{xsize}x#{ysize}! #{@tmp1} #{@tmp2}"
  system "#{CONVERT} -gravity east -splice #{558 - xsize}x0 -background white #{@tmp2} #{@tmp3} > /dev/null"
  system "#{CONVERT} -border 1x1 #{@tmp3} #{@tmp4}"
  #system "#{CONVERT} +dither -colors 16 #{@tmp4} #{@tmp5} > /dev/null"
  color = if $CONF['color'] == 'full' then '' else '-type GrayScale' end
  system "#{CONVERT} +dither #{color} #{@tmp4} #{@tmp5} > /dev/null"
  system "#{SIPS} -s format gif #{@tmp5} --out #{TMPDIR}/topdf_#{fnum}.gif > /dev/null"
  File.delete(file)
  puts "#{file} -> #{fnum}.gif (#{xsize},#{ysize})"
=begin
  #system "#{CONVERT} -gamma 1.2/1.2/1.2 temp1.bmp temp2.bmp > /dev/null"
  #system "#{SIPS} -Z 734 temp2.bmp --out temp3.bmp > /dev/null"
  #system "#{CONVERT} -unsharp 0x1.0+1.0+0.05 +dither -colors 16 temp3.bmp temp4.bmp > /dev/null"
  system "convert #{file} +dither -colors 16 #{file}.0"
  File.rename(file + ".0", file)
  #system "#{SIPS} -s dpiWidth 72 -s dpiHeight 72 -Z #{$HEIGHT} #{file} --out #{TMPDIR}/#{fnum}.jpg"
  #system "#{SIPS} -s format bmp -s dpiWidth 72 -s dpiHeight 72 -Z #{$HEIGHT} #{file} --out #{TMPDIR}/#{fnum}.bmp"
  #system "#{SIPS} -s format gif #{TMPDIR}/#{fnum}.bmp --out #{TMPDIR}/#{fnum}.gif"
  system "#{SIPS} -Z #{$HEIGHT} #{file} --out #{TMPDIR}/#{fnum}.jpg"
  system "#{SIPS} -s dpiWidth 72 -s dpiHeight 72 -Z #{$HEIGHT} #{file} --out #{TMPDIR}/#{fnum}.jpg"
  #File.delete(TMPDIR + '/' + fnum + '.bmp')
=end
end

def unzip
  puts "UNZIP: #{@zfile}"
  Zip::Archive.open(@zfile) do |ar|
    cnt = 0
    ar.each do |a|
      next if a.directory?
      fn = pickup(a)
      next if fn == nil
      convert(fn, cnt)
      cnt += 1
    end
  end
end

def create_pdf
  system "#{CONVERT} #{TMPDIR}/topdf_*.gif '#{@output}'"
end

def main
  init
  unzip
  create_pdf
  postproc
end

main
