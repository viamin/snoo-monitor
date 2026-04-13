ActiveSupport::Reloader.before_class_unload do
  SnooConnectionManager.disconnect!
rescue NameError
  nil
end
