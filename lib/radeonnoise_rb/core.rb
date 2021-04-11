# lib/radeonnoise_rb/core.rb

# This module will control the
# basic operation of a RadeonNoise
# application and configuration details.
module RadeonNoise
  # Base directory for hwmon
  BASEDIR = "/sys/class/hwmon"
  
  # Holds the list of cards
  @@cards = []
  
  def self.init
    # Iterate over hwmon subdirectories
    Dir.glob("#{BASEDIR}/*")
      # For each subdirectory, create an array
      .collect do |subd|
        # Read the uevent file
        File.read("#{subd}/device/uevent")
          .split(/\n/) # Divide it into lines
          .map do |line|
            parts = line.downcase.split("=") # Split into key-value pairs, lowercase
            k,v = parts[0].strip, parts[1].strip # Remove whitespace
            
            # Return the intermediate value as a hash containing
            # the hwmon subdirectory and the key-value pair
            {"dir" => subd.split("/").last, k => v}
          end
      end
      # Merge each array into a single hash; if the array
      # is empty, it will just be an empty hash
      .collect { |card| card.reduce Hash.new, :update }
      # We only want AMDGPU cards
      .select { |card| card['driver'] == "amdgpu" }
      # Convert each into a card object
      .each { |card| @@cards.push(RadeonCard.new(card)) }
      
      # Return the cards
      self.all
  end
  
  # Return all the cards
  def self.all() @@cards end
  
  # Holds data associated with each
  # Radeon card and provides access to
  # its fans and settings.
  class RadeonCard
    # Store the current settings for the 
    # graphics card:
    # # detail is the sysfs hardware object data
    # # sclk is the processor clock
    # # mclk is the memory clock
    # # pwm is whether fans are manual (true) or auto (false)
    # # fan_curve is a list of values for the fan speeds
    # # by temp.
    attr_reader :config, :cache
    
    # Constructor
    def initialize(hw)
      @config = {
        "detail" => hw,
        "sclk" => [], # Processor clock
        "mclk" => [], # Video memory clock
        
        # Regexes for various settings
        # Use these to detect the numbers for each
        "pwm" => /pwm\d*$/, # Fan power settings (0-255)
        "freqs" => /freq\d*_label/, # GPU frequencies
        "voltages" => /in\d*_label/, # Voltage inputs
        "temps" => /temp\d*_label/, # Temperatures
        "fans" => /fan\d*_input/, # List of available fans
        
        # Fan curve settings
        "fan_curve" => {},
      }
      
      d = "#{RadeonNoise::BASEDIR}/#{@config['detail']['dir']}"
      @cache = {
        'dir' => d,
        'vram_total' => File.read("#{d}/device/mem_info_vram_total"),
        'vbios' => File.read("#{d}/device/vbios_version"),
      }
      @cache.update({'fans' => fans})
      update
    end
    
    # Stat the current cached data
    def stat
      @cache
    end
    
    # Update the card values
    def update
      d = @cache['dir']
      @cache.update(udevice)
    end
    
    # Update core device stats
    def udevice
      d = @cache['dir']
      {
        'level' => File.read("#{d}/device/power_dpm_force_performance_level"),
        'sclk' => File.read("#{d}/device/pp_dpm_sclk"),
        'mclk' => File.read("#{d}/device/pp_dpm_mclk"),
        'pcie' => File.read("#{d}/device/pp_dpm_pcie"),
        'busy_proc' => File.read("#{d}/device/gpu_busy_percent"),
        'busy_mem' => File.read("#{d}/device/mem_busy_percent"),
      }
    end
    
    # Read fan data
    def fans
      d = @cache['dir']
      {
        
      }
    end
  end
end