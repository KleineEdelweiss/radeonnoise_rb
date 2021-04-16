# lib/radeonnoise_rb/parts.rb

# This module will handle several part objects
# and their abstract representations as components
# of a Radeon AMDGPU graphics card.
# 
# They operate to represent possible multi-unit
# components, such as fans, graphics cores, power
# data, PWM components, and temperature sensors
module Component
  # Inherited class
  # No implementations.
  class AbstractComponent
    # Headers is being used to refer to the
    # subclass-specific file prefixes and suffixes,
    # which are merged with the indices to generate
    # a full filename to be read from on each update.
    # 
    # Files associated with the object
    # Items of that type
    attr_reader :path, :prefixes, :current
    
    # Use the path (should end with 'hwmon[number]/*')
    # to glob all the files by the object type's regex, rg
    def initialize(rg, path)
      @current, @prefixes, @path = {}, pfx(rg, index(rg, path)), path.gsub("/*", "")
      update
    end
    
    # Attach regex components to
    # item indices, so they can be used
    # with the specific component items
    def index(rg, path)
      Dir.glob(path)
        .reject { |item| !item.match?(rg) }
        .collect { |item| item.split("/").last.gsub(/\D/, '').to_sym }
    end
    
    # Generate prefixes
    def pfx(rg, arr)
      pf = rg.source.gsub(/\\.*$/, '')
      arr.collect { |item| "#{pf}#{item}".to_sym }
    end
    
    # Update the local data
    # Set the values that don't change, permanently
    def update
      puts "method 'update' is not implemented for #{self.class}, yet"
    end
  end
  
  # Temp loader class
  class Temp < AbstractComponent
    # For temp, will read the files:
    # -input (current temp)
    # -label (name of sensor)
    # -crit (critical max temperature)
    # -crit_hyst (critical hysteresis temp)
    # Permanent values are crit, crit_hyst, and label
    def update
      # Create a card index for each prefix
      @prefixes.each { |pref| @current[pref] = {} }
      
      # Fill in all the data, only fill the permanent ones
      # on the first load.
      # 
      # Label should be stripped of trailing spaces, and
      # all other values should be converted to a float and
      # divided by 1000, to change back into degrees Celsius
      @current.each do |k,v|
        @current[k][:critical] ||= File.read("#{@path}/#{k}_crit").to_f / 1000
        @current[k][:hysteresis] ||= File.read("#{@path}/#{k}_crit_hyst").to_f / 1000
        @current[k][:label] ||= File.read("#{@path}/#{k}_label").strip
        @current[k][:current] = File.read("#{@path}/#{k}_input").to_f / 1000
      end
    end
  end
end