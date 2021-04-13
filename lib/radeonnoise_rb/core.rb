# lib/radeonnoise_rb/core.rb

# This module will control the
# basic operation of a RadeonNoise
# application and configuration details.
module RadeonNoise
  # Base directory for hwmon
  BASEDIR = "/sys/class/hwmon"
  
  # List of cards
  @@cards = []
  
  # Initialize the RadeonNoise controls
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
      .each { |card| @@cards.push(AMDGPUCard.new(card)) }
      
      # Return the cards
      self.all
  end
  
  # Return all the cards
  def self.all() @@cards end
    
  # Return whether the user is root
  def self.root() `id -u`.strip.to_i == 0 end
  
  # Holds data associated with each
  # AMDGPU card and provides access to
  # its fans and settings.
  class AMDGPUCard
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
        "power" => /power\d*_average/, # GPU processor power consumption
        "voltages" => /in\d*_label/, # Voltage inputs
        "temps" => /temp\d*_label/, # Temperatures
        "fans" => /fan\d*_input/, # List of available fans
        
        # Long filenames that should be stored
        # for quick access
        'dpm_level' => "device/power_dpm_force_performance_level",
        
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
      @cache.update(udevice).update(freqs).update(pcie)
    end
    
    # Update core device stats
    def udevice
      d = @cache['dir']
      {
        'level' => File.read("#{d}/device/power_dpm_force_performance_level"),
        'busy_proc' => File.read("#{d}/device/gpu_busy_percent"),
        'busy_mem' => File.read("#{d}/device/mem_busy_percent"),
      }
    end
    
    # PWM (fan power)
    def pwm
      d = @cache['dir']
      {
        
      }
    end
    
    # Read fan data
    def fans
      d = @cache['dir']
      {
        
      }
    end
    
    # Voltage
    def volts
      d = @cache['dir']
      {
        
      }
    end
    
    # Power consumption
    def power
      d = @cache['dir']
      Dir.glob("#{d}/*")
        .reject { |i| !i.match?(@config['power']) }
        .collect { |i| nil }
      {
        
      }
    end
    
    # Frequencies
    # These are handled by only the sclk
    def freqs
      d = @cache['dir']
      {
        'sclk' => active_s(File.read("#{d}/device/pp_dpm_sclk"))
          .collect { |item| item.to_f },
        'mclk' => active_s(File.read("#{d}/device/pp_dpm_mclk"))
          .collect { |item| item.to_f },
      }
    end
    
    # PCIe speed
    def pcie
      {
        'pcie' => active_s(File.read("#{@cache['dir']}/device/pp_dpm_pcie"))
          .collect { |item| item.split(",").last.gsub(/\W/, '') },
      }
    end
    
    # Temperatures
    def temps
      d = @cache['dir']
      {
        
      }
    end
    
    # Split multi-line read-ins
    # and then select the active option
    # only (for settings)
    def active_s(data)
      data.split(/\n/)
        .reject { |item| !item.strip.match?(/\*$/) }
        .collect { |item| item.split(":").last.strip }
    end
    
    # Change performance type (manual / auto)
    # /device/power_dpm_force_performance_level
    # "manual" / "auto"
    def force_perf(setting)
      if !RadeonNoise.root then
        puts "You need superuser/root permissions to use setters in this module"
      elsif ["manual", "auto"].include?(setting) then
        File.write("#{@cache['dir']}/#{@config['dpm_level']}", setting, mode: "r+")
      else
        puts "DPM force setting can only be 'manual' or 'auto'"
      end
    end
  end
end