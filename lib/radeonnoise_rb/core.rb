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
      .select { |card| card['driver'] == "amdgpu"}
  end
end