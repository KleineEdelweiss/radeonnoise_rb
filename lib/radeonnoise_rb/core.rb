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
    attr_reader :config
    
    # Constructor
    def initialize(hw)
      @config = {
        "detail" => hw,
        "sclk" => [],
        "mclk" => [],
        "pwm" => false,
        "fan_curve" => {}
      }
      update
    end
    
    # Update the card values
    def update
      
    end
  end
end