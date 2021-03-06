# amathema - LaTeX equations as PNG
# =================================
# GET /m/#{encoded equation}.png where equation is a Base64 for URL (+ to -, / to _) 
# encoded  LaTeX equation (e.g. [equation].pack('m').tr('+/','-_').strip)
#
# Code convention: 'equation' is encoded, 'dequation' is decoded.
require 'rubygems'
require 'sinatra'
require 'markaby'
require 'digest/md5'

# Configuration
CACHE_DIR = "./cache/"
PIXEL_HEIGHT = 30
set :host, 'localhost'
set :port, 2804

set :environment, :production
enable :lock

# create cache directory on startup
configure do
  Dir.mkdir(CACHE_DIR) unless File.directory? CACHE_DIR
end

helpers do
  def decode_equation(equation)
    equation.tr('-_', '+/').unpack('m')[0]
  end
  
  def valid_equation?(equation)
    equation =~ /^[A-Za-z0-9\-\_=]+$/
  end
  
  def construct_LaTeX_document(dequation)
    "\\documentclass[]{article} \\pagestyle{empty} \\usepackage[utf8]{inputenc}" +
    " \\begin{document} $#{dequation}$ \\end{document}"
  end
end

get '/m/*.png' do
  equation = params[:splat][0]
  if valid_equation? equation
    digest = Digest::MD5.hexdigest(equation)
    png_file = File.join(CACHE_DIR, "#{digest}.png")
    # not in cache?
    unless File.exists? png_file
      dequation = decode_equation(equation)
      tex_file = File.join(CACHE_DIR, "#{digest}.tex")
      File.open(tex_file, "w"){|f| f.write(construct_LaTeX_document(dequation))}
      %x{latex -halt-on-error #{tex_file}}
      %x{dvipng -T tight -D #{PIXEL_HEIGHT*7.227} #{digest}.dvi -o #{png_file}}
      begin
        File.delete("#{digest}.log")
        File.delete("#{digest}.aux")
        File.delete("#{digest}.dvi")
      rescue Exception => e
        raise Sinatra::NotFound
      end
    end
    send_file(png_file)
  else
    raise Sinatra::NotFound
  end
end

not_found do
  markaby = Markaby::Builder.new
  markaby.xhtml_strict do
    head do
      title "404"
    end
    body do
      h1{b{"Invalid URL"}}
      p{"Only GET requests to '/m/\#{Base64 for URL encoded LaTeX equation}.png' supported"}
    end
  end
  markaby.to_s
end