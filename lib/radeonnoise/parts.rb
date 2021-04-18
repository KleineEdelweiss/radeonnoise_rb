# lib/radeonnoise/parts.rb

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
      # Initialize the object variables
      @current, @prefixes, @path = {}, pfx(rg, index(rg, path)), path.gsub("/*", "")
      
      # Create a card index for each prefix
      @prefixes.each { |pref| @current[pref] = {} }
      update
    end # End constructor
    
    # Attach regex components to
    # item indices, so they can be used
    # with the specific component items
    def index(rg, path)
      Dir.glob(path)
        .reject { |item| !item.match?(rg) }
        .collect { |item| item.split("/").last.gsub(/\D/, '').to_sym }
    end # End index
    
    # Generate prefixes
    def pfx(rg, arr)
      rg.source.gsub(/\\.*$/, '').then { |pf|
        arr.collect { |item| "#{pf}#{item}".to_sym }}
    end # End prefix
    
    # Update the local data
    # Set the values that don't change, permanently
    def update
      puts "method 'update' is not implemented for #{self.class}, yet"
    end # End update
  end # End AbstractComponent class
  
  # Temp loader class
  class Temp < AbstractComponent
    # For temp, will read the files:
    # -input (current temp)
    # -label (name of sensor)
    # -crit (critical max temperature)
    # -crit_hyst (critical hysteresis temp)
    # Permanent values are crit, crit_hyst, and label
    def update
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
    end # End update method
  end # End Temp class
    
  # Fan loader class
  class Fan < AbstractComponent
    # Read in the enabled state, max state, and target state.
    # 
    # Although _target can be read in and manipulated, it is pointlessly
    # risky to manipulate it, when the PWM controller in the core module
    # already does this.
    # 
    # Due to it being a mechanical RPM target, it will also
    # CONSTANTLY need to readjust, rather than just keeping the pulse width
    # setting the same and letting the motor do the lifting. Setting this
    # forces the driver to take an active role in manipulating the speed, when
    # it changes by even a small margin.
    # 
    ## Whether I will add this later or recommend users overload it themselves, ##
    ## I am not yet sure. Unlike the power cap, this does not provide any real ##
    ## benefit, and it can freeze up the driver, at least as tested on my system. ##
    def update
      @current.each do |k,v|
        # If the value, when converted to an integer, is 1, it is enabled.
        # If it is 1, the result should be true. `.zero?` returns true if 0,
        # so invert it.
        @current[k][:enabled] = !File.read("#{@path}/#{k}_enable").to_i.zero?
        # The current speed of the fan
        @current[k][:rpm_current] = File.read("#{@path}/#{k}_input").to_i
        # As the below 2 values, _min and _max, cannot be changed, I have
        # implemented them as such.
        # 
        # _min is probably locked by firmware or the card's BIOS. However,
        # it is here, anyway. Even root cannot modify this.
        @current[k][:rpm_min] ||= File.read("#{@path}/#{k}_min").to_i
        # _max does not seem editable either, but unlike _min, it is
        # definitely useful to know the card's max RPM.
        @current[k][:rpm_max] ||= File.read("#{@path}/#{k}_max").to_i
      end
    end # End update
  end # End Fan class
end # End Component module