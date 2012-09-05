require 'bundler'
Bundler.require
autoload :Base64, 'base64'

module StarfleetMe

  class Generator
    Infinity = 1.0/0

    SHIPS = {
      (0..100) => './public/uss_tiny.png',
      (101..300) =>  './public/uss_small.png',
      (301..499) => './public/uss_medium.png',
      (500..Infinity) => './public/uss_large.png'
    }

    FRAMES = 8

    attr_reader :source

    def initialize(image_source=url)
      @source = CGI.unescape image_source.to_s
    end

    def animate
      steps = []
      x = 0
      y = height/6
      xstep = (width/FRAMES).ceil
      ystep = (y/FRAMES + 1).ceil
      (FRAMES).times do |index|
        if x <= width && y >= 0
          steps << "-page +#{x}+#{y} #{ship}"
        end
        x += xstep
        y -= ystep
      end
      cmd = "convert -delay 14 -loop 100 -dispose none #{input_path} -dispose previous #{steps.join(" ")} #{output_path}"
      puts cmd
      system cmd
    end

    def digest
      @digest ||= Digest::SHA1.hexdigest(source)
    end

    def download
      @download ||= system("mkdir -p tmp; curl -L -o #{input_path} #{source}")
    end

    def height
      size[1].to_i
    end

    def size
      @size ||= `identify -format "%G" #{input_path}`.split /[x\r?\n]/
    end

    def ship
      @ship ||= SHIPS.each do |range, name|
        break name if range.include? width
      end
    end

    def width
      size[0].to_i
    end

    def input_path
      @input_path ||= File.expand_path("./tmp/#{digest}")
    end

    def output_path
      @output_path ||= File.expand_path("./tmp/#{digest}.gif")
    end

    def valid?
      source && !source.empty? && download
    end

    # convert -delay 50 -dispose none sandrot.jpg -dispose previous -page +0+150 small_ship.png -page +150+100 small_ship.png -page +300+50 small_ship.png -page +450+0 small_ship.png -loop 0 anim.gif

  end
end

ENV['DATABASE_URL'] ||= 'postgres://localhost/starfleet-me'
DB = Sequel.connect(ENV['DATABASE_URL'])
DB.test_connection

set(:migration_method) do
  ENV.has_key?('RESET') ? 'create_table!' : 'create_table?'
end

configure :development do
  require 'logger'
  DB.loggers << Logger.new($stdout)
end

DB.send(settings.migration_method, :gifs) do
  primary_key :id
  File :data
  String :source, :index => true
  DateTime :updated_at
end

DB_GIFS = DB[:gifs]

get '/' do
  if params[:source] && !params[:source].empty?
    generator = StarfleetMe::Generator.new params[:source]
    etag generator.digest
    gif = DB_GIFS.where(source: generator.source).first
    if gif.nil?
      if generator.valid?
        generator.animate
        if File.exists? generator.output_path
          binary = File.open(generator.output_path, 'r:binary') {|f| p f.external_encoding.name; f.read }
          binary = Base64.encode64(binary)
          DB_GIFS.insert(
            source: generator.source,
            data: binary,
            updated_at: Time.now
          )
        end
        GC.start
        send_file generator.output_path, :type => :gif
      end
    else
      output_path = './tmp/anim.gif'
      File.open(output_path, 'wb') do |f|
        f.write(Base64.decode64(gif[:data]))
      end
      send_file output_path, :type => :gif
    end
  end

  haml :index
end

get '/foo' do
  etag Digest::SHA1.hexdigest('123')
  p env['HTTP_IF_NONE_MATCH']
  p response['ETag']
  Time.now.to_s
end
