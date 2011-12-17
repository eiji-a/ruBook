#
# Pdf
#

module PDF

class Main
  VERSION = '%PDF-1.2'

  def initialize(io, pagesize, mediabox, contents)
    @io = io
    @objsizes = []
    @pagesize = pagesize
    @mediabox = mediabox
    @contents = contents
  end

  def start(npage)
    object = VERSION + "\r\n"
    @objsizes << object.size
    @io.print object

    # OBJECT 1: Catalog
    put_obj <<EOF
<<
/Type /Catalog
/ViewerPreferences<</Direction/R2L>>
/Pages 3 0 R
>>
EOF
    # OBJECT 2: CreationDate
    put_obj <<EOF
<<
/CreationDate (D:#{Time.now.strftime("%Y%m%d%H%M%S")}+09'00')
/Title <ABCDEFG>
>>
EOF
    # OBJECT 3: Pages
    put_obj <<EOF
<<
/Type /Pages
/Kids [#{page_ref(npage)}]
/Count #{npage}
>>
EOF
  end
  
  def put_obj(body)
    num = @objsizes.size
    object = <<EOF
#{num} 0 obj
#{body}endobj
EOF
    object.gsub!("\r\n", "\n")
    object.gsub!("\n", "\r\n")
    @objsizes << object.size
    @io.print object
  end

  def finish
    object = <<EOF
xref
0 #{@objsizes.size + 1}
0000000000 65535 f
EOF
    offset = 0
    @objsizes.each do |os|
      offset += os
      object += sprintf("%010d 00000 n\r\n", offset)
    end
    object += <<EOF
trailer
<<
/Size #{@objsizes.size}
/Root 1 0 R
/Info 2 0 R
>>
startxref
#{offset}
%%EOF
EOF
    #object.gsub!("\r\n", "\n")
    #object.gsub!("\n", "\r\n")
    @io.print object
  end

  def page_ref(npage)
    pages = ''
    npage.times do |i|
      pages += " #{i * 3 + 4} 0 R "
    end
    pages
  end

  def put_page(num, x, y, file)
    object = <<EOF
<<
/Type /Page
/Parent 3 0 R
/Resources
<<
/XObject << /Im#{num} #{num * 3 + 4 + 1} 0 R >>
/ProcSet [ /PDF /ImageC ]
>>
/MediaBox [ 0 0 #{@mediabox[0]} #{@mediabox[1]} ]
/Contents #{num * 3 + 4 + 2} 0 R
>>
EOF
    put_obj(object)

    body = ''
    File.open(file) do |fp|
      body = fp.read
    end
    object = <<EOF
<<
/Type /XObject
/Subtype /Image
/Name /Im#{num}
/Width #{@pagesize[0]}
/Height #{@pagesize[1]}
/Filter [/DCTDecode]
/ColorSpace /DeviceRGB
/BitsPerComponent 8
/Length #{File.size(file)} >>
stream
#{body}endstream
EOF
    put_obj(object)

    stream = <<EOF
q
#{@contents[0]} 0 0 #{@contents[1]} 0 0 cm
/Im#{num} Do
Q
EOF
    object = <<EOF
<< /Length #{stream.size} >>
stream
#{stream}endstream
EOF
    put_obj(object)
  end
end
end

