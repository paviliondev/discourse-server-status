# frozen_string_literal: true
class PluginManager::PluginSerializer < ::PluginManager::BasicPluginSerializer
  attributes :display_name,
             :url,
             :authors,
             :about,
             :version,
             :owner,
             :contact_emails,
             :installed_sha,
             :git_branch,
             :branch_url,
             :test_status,
             :test_backend_coverage,
             :log,
             :owner,
             :support_url,
             :test_url,
             :from_file,
             :category_id

  def log
    log = ::PluginGuard::Log.list(object.name).first
    PluginManager::LogSerializer.new(log, root: false).as_json
  end

  def include_log?
    object.status === PluginManager::Manifest.status[:incompatible] ||
    object.status === PluginManager::Manifest.status[:tests_failing]
  end

  def owner
    PluginManager::OwnerSerializer.new(object.owner, root: false).as_json
  end

  def include_owner?
    object.owner.present?
  end
end
