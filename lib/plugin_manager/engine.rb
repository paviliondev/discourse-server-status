class PluginManager::Engine < ::Rails::Engine
  engine_name PluginManager::NAMESPACE
  isolate_namespace PluginManager
end