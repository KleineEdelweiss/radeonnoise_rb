# lib/radeonnoise_rb/core.rb

# This module will control the
# basic operation of a RadeonNoise
# application and configuration details.
module RadeonNoise
  # Base directory for hwmon
  BASEDIR = "/sys/class/hwmon"
  
  # List of cards
  @cards = []
  
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
            k,v = parts[0].strip.to_sym, parts[1].strip # Remove whitespace
            
            # Return the intermediate value as a hash containing
            # the hwmon subdirectory and the key-value pair
            {dir: subd.split("/").last, k => v}
          end
      end
      # Merge each array into a single hash; if the array
      # is empty, it will just be an empty hash
      .collect { |card| card.reduce Hash.new, :update }
      # We only want AMDGPU cards
      .select { |card| card[:driver] == "amdgpu" }
      # Convert each into a card object
      .each { |card| @cards.push(AMDGPUCard.new(card)) }
      
      # Return the cards
      self.all
  end
  
  # Return all the cards
  def self.all() @cards end
    
  # Return whether the user is root
  def self.root
    if `id -u`.strip.to_i == 0 then
      return true
    else
      puts "You need superuser/root permissions to use setters in this module"
    end
    false
  end
  
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
    
    PROTECTLVL = [:no_prot, :min_prot, :low_prot, :med_prot, :high_prot, :max_prot]
    PWMLVL = {0 => :none, 1 => :manual, 2 => :auto}
    PWMERR = "ERROR: accepted PWM type values are #{PWMLVL.values} or #{PWMLVL.invert.values}"
    
    # Constructor
    def initialize(hw)
      # Initialize the card's config
      @config = {
        detail: hw,
        sclk: [], # Processor clock
        mclk: [], # Video memory clock
        
        # Regexes for various settings
        # Use these to detect the numbers for each
        pwm: /pwm\d*$/, # Fan power settings (0-255)
        freqs: /freq\d*_label/, # GPU frequencies
        power: /power\d*_average/, # GPU processor power consumption
        voltages: /in\d*_label/, # Voltage inputs
        temps: /temp\d*_label/, # Temperatures
        fans: /fan\d*_input/, # List of available fans
        
        # Quick access to some files
        # Manual/Auto clocking of processor
        dpm_level: "device/power_dpm_force_performance_level",
        # Power cap (used in a setting, as well as a read)
        pcap: "power1_cap",
        
        # Fan curve settings
        fan_curve: {},
        
        # Allow unsafe operations
        protection: :max_prot,
      }
      
      # Initialize the card's stat cache
      @cache = "#{RadeonNoise::BASEDIR}/#{@config[:detail][:dir]}".then { |d| {
        dir: d,
        power_max: File.read("#{d}/power1_cap_max").to_i,
        vram_total: File.read("#{d}/device/mem_info_vram_total").to_f,
        vbios: File.read("#{d}/device/vbios_version").strip,
      }}
      update
    end # End constructor
    
    # Stat the current cached data
    def stat() @cache end
    
    # Update the card values
    def update
      @cache.update(udevice)
        .update({slot: pcie})
        .update(pwm)
        .update(freqs)
        .update(volts)
        .update({fans: fans})
    end # End abstract update function
    
    # Update core device stats
    def udevice
      @cache[:dir].then { |d| {
        level: File.read("#{d}/#{@config[:dpm_level]}").strip,
        busy_proc: File.read("#{d}/device/gpu_busy_percent").to_f,
        busy_mem: File.read("#{d}/device/mem_busy_percent").to_f,
      }}
    end # End core device data reader
    
    # PWM (fan power)
    def pwm
      @cache[:dir].then { |d| {
        pwm_control: pwmtype(File.read("#{d}/pwm1_enable").to_i),
        pwm_max: File.read("#{d}/pwm1_max").to_i,
        pwm_current: File.read("#{d}/pwm1").to_i,
      }}
    end # End PWM
    
    # PWM control type
    # Accepts: [Integer, String, Symbol]
    # 
    # If String, convert to lowercase w/o whitespace, then
    # check if it's an Integer or Symbol, and recurse.
    # 
    # If Integer, check if in PWMLVL.
    # If Symbol, check if in inverse hash of PWMLVL.
    # Return `nil`, if not present -- up to user how to handle.
    # If anything else, return error message.
    def pwmtype(val)
      case
      when String === val # Try to recursively check on conversion
        val.downcase.strip.then { |v| v.match?(/^\d+$/) ? pwmtype(v.to_i) : pwmtype(v.to_sym) }
      when Integer === val # Check the constant directly
        PWMLVL[val] || PWMERR
      when Symbol === val # Invert constant, check
        PWMLVL.invert[val] || PWMERR
      else # Wrong class of input
        "ERROR: wrong arg type (#{val.class}) for `pwmtype`. Accepts: [Integer, String, Symbol]"
      end
    end # End PWM type checker
    
    # Read fan data
    def fans
      @cache[:dir].then { |d| {
        
      }}
    end # End fans
    
    # Voltage
    # The inputs were re-classified from a previous commit:
    # they have a specific meaning and are not actually
    # variable. in0 is the graphics processor, while in1
    # is the northbridge, if a sensor is present.
    # 
    # As such, will update with a value or empty.
    def volts
      [@cache[:dir], "in0_input", "in1_input"].then { |d,c,n| {
        volt_core: File.read("#{d}/#{c}").to_f,
        volt_northbridge: File.exist?("#{d}/#{n}") ? File.read("#{d}/#{n}").to_f : nil,
      }}
    end # End voltage reader
    
    # Power consumption
    # This is 
    def power
      @cache[:dir].then { |d| {
        'power_cap' => File.read("#{d}/#{@config['pcap']}").strip,
        'power_usage' => File.read("#{d}/power1_average").strip,
      }}
    end # End power reader
    
    # Frequencies
    # sclk is the processor clock
    # mclk is the VRAM clock
    def freqs
      @cache[:dir].then { |d| {
        freq_core: active_s(File.read("#{d}/device/pp_dpm_sclk"))
          .collect { |item| item.to_f },
        freq_vram: active_s(File.read("#{d}/device/pp_dpm_mclk"))
          .collect { |item| item.to_f },
      }}
    end # End frequency reader
    
    # PCIe speed
    # Although this is a 
    def pcie
      active_s(File.read("#{@cache[:dir]}/device/pp_dpm_pcie"))
      .collect do |item| 
        item.split(",").then { |tf, mul|
          {multiplier: mul.gsub(/\W/, ''), tfspeed: tf}}
      end
    end # End PCIe setting reader
    
    # Temperatures
    def temps
      @cache[:dir].then { |d| {
        
      }}
    end # End temps
    
    # Split multi-line read-ins
    # and then select the active option
    # only (for settings)
    def active_s(data)
      data.split(/\n/)
        .reject { |item| !item.strip.match?(/\*$/) }
        .collect { |item| item.split(":").last.strip }
    end # End abstract active setting reader
    
    # Warn the user about unsafe operations
    def unsafe_warning(fn)
      ("+" * 20).then { |sep| <<~MSG
          #{sep}\n'#{fn}' is a potentially damaging operation, and you must supply
          the parameter 'force=true' to allow it to complete. This function
          may cause graphics card crashes or damage to components, if used
          incorrectly. During erroneous usage, data loss/corruption, due to a system
          crash might be considered 'optimistic'.\n#{sep}
        MSG
        }.then { |msg| puts msg }
      false
    end # End unsafe warning
    
    # Set the level of unsafe protection
    def set_protection(val)
      if RadeonNoise.root then
        if PROTECTLVL.include?(val) then
          @config[:protection] = val
        else
          ("+" * 20).then { |sep| <<~ERR
            #{sep}\n'#{val}' is not a valid protection setting
            Valid options are: #{PROTECTLVL}
            No change\n#{sep}
          ERR
            }.then { |e| puts e }
        end
      end
    end # End setter for protection level
    
    # Change the power cap on the card -- microWatts
    def set_pcap(uwatts, force=false)
      # Potentially potentially damaging operation, must supply force param
      if !force then
        return unsafe_warning('set_pcap')
      else
        # Make sure user is root
        if RadeonNoise.root then
          # Writes the minimum value, as the minimum is either below the maximum
          # power cap or the maximum power cap itself. Absolute value
          # is applied, so that a negative cannot be entered
          uwatts.to_i.then { |w|
            File.write("#{@cache[:dir]}/#{@config[:pcap]}", [w, @cache[:power_max]].min.abs, mode: "r+")}
        end
      end
    end # End pcap setter
    
    # Change performance type (manual / auto)
    # /device/power_dpm_force_performance_level
    # "manual" / "auto"
    def set_dpm(setting)
      if RadeonNoise.root then
        if [:manual, :auto].include?(setting) then
          File.write("#{@cache[:dir]}/#{@config[:dpm_level]}", setting, mode: "r+")
        else
          puts "DPM force setting can only be 'manual' or 'auto'"
        end
      end
    end # End dpm setter
    
    # Set the PWM type
    # ONLY USABLE AS ROOT
    # 
    # Takes a user-entered value to choose the PWM mode
    # setting -- no control, manual control, or automatic control.
    # 
    # Use `pwmtype` to check validity. If invalid, just print an error.
    # Otherwise, if the value is returned as a symbol, pass it back to
    # produce and integer to write to the file. Otherwise, write the
    # returned integer directly
    def set_pwmt(val)
      if RadeonNoise.root then
        pwmtype(val).then { |v| # If the pwmtype output is valid
          if Integer === v or Symbol === v then
            (Integer === v ? v : pwmtype(v)).then { |data| # Only use Integers
              File.write("#{@cache[:dir]}/pwm1_enable", data, mode: "r+") }
          else # If the pwmtype output is any kind of error message
            puts "#{v}"
          end
        }
      end
    end # End setter for PWM type
    
    # PWM speed controller
    def set_pwm(val)
      if RadeonNoise.root then
        
      end
    end # End setter for PWM speed
  end # End class AMDGPUCard
end # End module