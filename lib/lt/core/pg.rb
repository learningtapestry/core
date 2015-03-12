require 'active_record'

module LT
  module PG
    class << self
      def begin_transaction
        ActiveRecord::Base.connection.execute("BEGIN")
      end
      def commit_transaction
        ActiveRecord::Base.connection.execute("COMMIT")
      end
      def rollback_transaction
        ActiveRecord::Base.connection.execute("ROLLBACK")
      end
    end
  end
end
