module LT
  module WebApp
    module Views
      module Helpers
        def set_title(title)
          @layout[:title] = "Learning Tapestry - #{title}"
        end

        # Purpose: Render an ERB page, and including required parameters
        def vrender(page, options ={})
          erb(page, locals: options.merge({layout: @layout}))
        end
      end

      def self.registered(app)
        app.helpers Views::Helpers
      end
    end
  end
end
