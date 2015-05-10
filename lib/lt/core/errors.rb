module LT
  class BaseException < Exception; end
  class ParameterMissing < BaseException; end
  class InvalidParameter < BaseException; end
  class Critical < BaseException; end
  class LoginError < BaseException; end
  class UserNotFound < LoginError; end
  class PasswordInvalid < LoginError;end
  class FileNotFound < BaseException; end
  class PathNotFound < BaseException; end
  class ModelNotFound < BaseException; end
  class InvalidFileFormat < BaseException; end
  class APIRequestFailure < BaseException; end
end
