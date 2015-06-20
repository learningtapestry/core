require 'ostruct'
require 'erubis'

module LT

  # A small wrapper around OpenStruct for storing configuration values.
  class Configuration < OpenStruct

    def initialize(root_path, options = {})
      super()
      @root_path = root_path
      @filename = options[:filename] || '.env'
    end

    def self.load(root_path, options = {})
      config = new(root_path, options)
      config.load(File.readlines(config.path))
      config
    end

    def load(var_defs)
      var_defs.each do |var_def|
        k, v = var_def.chomp.split('=', 2)
        self[k] = v
      end
    end

    def save
      File.open(path, 'w') do |f|
        to_h.each do |k, v|
          f.puts "#{k}=#{v}"
        end
      end
    end

    def path
      File.join(@root_path, @filename)
    end

    def render(template)
      Erubis::Eruby.new(template).result(self.to_h)
    end
  end
end
