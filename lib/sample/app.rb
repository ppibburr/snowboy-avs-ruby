require 'avs'

class SnowboyAVS < AVS::OnDeviceWake
  attr_accessor :resource_path, :snowboy, :pac
  def initialize conf={}
    @resource_path = (conf['resources'] ||= File.join(File.dirname(__FILE__), "..", "..", "resources"))
    
    super(client_id:     conf['client_id'],
          client_secret: conf['client_secret'], 
          refresh_token: conf['refresh_token'])
   
    @pac     = Snowboy::Capture::PortAudio.new
    @snowboy = Snowboy::Detector.new(model: conf['snowboy-model'], resource: conf['snowboy-resource'], gain: conf['snowboy-gain'], sensitivity: conf['snowboy-sensitivity'])
    
    app = self
    
    set_listener do |time=5|
      app.play app.resource('alert.wav')
      
      app.record f='./input.wav', time
      
      Thread.new do
        app.play app.resource('alert.wav')
      end
      
      next f
    end
    
    set_speak do |data|
      IO.popen('bash -c "mpg321 -"', 'r+') do |io|
        io.puts data
      end    
    end
  end
  
  def record out, time=5
    if (rec = `which rec`.strip) != ''
      `rec -d -c 1 -r 16000 -e signed -b 16 #{out} trim 0 #{time}`
    elsif  (rec = `which arecord`.strip) != ''
      `#{rec} -r 16000 -f S16_LE -d #{time} #{out}`
    end  
  end
  
  def play file
    if file =~ /\.mp3$/
      `mpg321 #{file}`
    
      return
    end
    
    if ((play=`which play`) != '') or ((play=`which aplay`) != '')
      `#{play.strip} #{file}`
    else
      puts "no player found"
    end  
  end
  
  def run
    Thread.abort_on_exception = true
    pac.run(snowboy.sample_rate , snowboy.n_channels , snowboy.bits_per_sample ) do |data, length|;
      if snowboy.run_detection(data, length, false) > 0
        wake
      end
    end
    
    super
  end

  def resource file
    File.expand_path(File.join(@resource_path, file))
  end
end
