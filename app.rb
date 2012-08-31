require 'bundler'
Bundler.require

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

    def download
      @download ||= system("mkdir -p tmp; curl -L -o #{input_path} #{@source}")
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
      @input_path ||= File.expand_path("./tmp/image")
    end

    def output_path
      @output_path ||= File.expand_path("./tmp/anim.gif")
    end

    def valid?
      @source && !@source.empty? && download
    end

    # convert -delay 50 -dispose none sandrot.jpg -dispose previous -page +0+150 small_ship.png -page +150+100 small_ship.png -page +300+50 small_ship.png -page +450+0 small_ship.png -loop 0 anim.gif

  end
end

get '/' do
  generator = StarfleetMe::Generator.new params[:source]
  etag Digest::SHA1.hexdigest(params[:source].to_s)
  if generator.valid?
    generator.animate
    send_file generator.output_path, :type => :gif
  else
    haml :index
  end
end

get '/foo' do
  etag Digest::SHA1.hexdigest('123')
  p env['HTTP_IF_NONE_MATCH']
  p response['ETag']
  Time.now.to_s
end
