require 'sinatra/base'

module LT
  module WebApp
    module Registerable
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        # If called with a block, the block is stored until the module is registered
        # with Sinatra.
        # If called with an application object, evaluates the stored block in the app
        # context.
        def registered(app=nil, &blk)
          if blk
            @on_register = blk
          elsif app
            app.send(:helpers, self::Helpers) if self.constants.include?(:Helpers)
            app.instance_eval(&@on_register)
          end
        end
      end
    end
  end
end
