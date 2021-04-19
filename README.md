### OVERVIEW ###
"radeonnoise" is a port of my other Linux ``amdgpu`` project done in Elixir. It will allow monitoring and control of Radeon graphics cards that use the ``amdgpu`` driver.

I had previously hacked together this same library (also in Ruby) for a personal app, and I was planning to port the whole thing to Elixir. However, I just find Ruby more enjoyable and speedy to code in, and with Ruby 3.0.0's release, the Ractor model allows Ruby to bypass the GIL, so performance hits should be far less than the original private project.

Unlike the Elixir version, this is going to be a pluggable module and is not intended to inherently be a server unto itself.

The name is a play on Raildex's "Radio Noise Project", with the Misaka clones.

# TO-DO
1) Clean out unnecessary/unused code
1) Add better documentation
1) Add a fan curve configuration system
1) Add a fan curve controller
1) Possibly try to connect the driver's version data with an FFI library or similar.

# INSTALLATION
```
gem install radeonnoise
```