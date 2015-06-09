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
      File.readlines(config.path).each do |line|
        k, v = line.chomp.split('=', 2)
        config[k] = v
      end
      config
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
