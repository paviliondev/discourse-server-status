# frozen_string_literal: true
# name: discourse-plugin-manager
# about: Pavilion's Plugin Manager
# version: 0.2.0
# authors: Angus McLeod
# url: https://github.com/paviliondev/discourse-plugin-manager

hide_plugin if self.respond_to?(:hide_plugin)

register_asset "stylesheets/common/plugin-manager.scss"
register_asset "stylesheets/mobile/plugin-manager.scss", :mobile

register_svg_icon "bug"
register_svg_icon "far-check-circle"
register_svg_icon "far-times-circle"
register_svg_icon "code-branch"
register_svg_icon "vial"
register_svg_icon "building"
register_svg_icon "far-life-ring"
register_svg_icon "far-question-circle"

%w(
  ../lib/plugin_manager.rb
  ../lib/plugin_manager_store.rb
).each do |path|
  load File.expand_path(path, __FILE__)
end

after_initialize do
  PluginManagerStore.commit_cache

  %w(
    ../mailers/plugin_mailer.rb
    ../app/jobs/scheduled/update_plugin_test_statuses.rb
    ../app/jobs/scheduled/update_plugins.rb
    ../app/jobs/regular/send_plugin_notification.rb
    ../app/controllers/plugin_manager/plugin_controller.rb
    ../app/controllers/plugin_manager/plugin_status_controller.rb
    ../app/controllers/plugin_manager/plugin_user_controller.rb
    ../app/serializers/plugin_manager/log_serializer.rb
    ../app/serializers/plugin_manager/plugin_serializer.rb
    ../app/serializers/plugin_manager/plugin_user_serializer.rb
    ../app/serializers/plugin_manager/plugin_status_serializer.rb
    ../app/serializers/plugin_manager/owner_serializer.rb
    ../config/routes.rb
  ).each do |path|
    load File.expand_path(path, __FILE__)
  end

  unless Rails.env.test?
    PluginManager::Plugin.update_plugins
    PluginManager::Plugin.update_local_plugins
    PluginManager::Plugin.update_test_statuses
  end

  user_key_suffix = 'plugin-registrations'
  user_updated_at_key_suffix = 'plugin-registrations-updated-at'

  add_to_class(:user, :plugin_registered?) do |domain, plugin_name|
    key = "#{plugin_name}-#{user_key_suffix}"
    custom_fields[key].present? && custom_fields[key].include?(domain)
  end

  add_to_class(:user, :register_plugins) do |domain, plugin_names|
    plugin_names.select { |n| PluginManager::Plugin.exists?(n) }.each do |name|
      key = "#{name}-#{user_key_suffix}"
      custom_fields[key] ||= []
      custom_fields[key].push(domain) unless custom_fields[key].include?(domain)
    end
    custom_fields["#{domain}-#{user_updated_at_key_suffix}"] = DateTime.now.iso8601(3)

    save_custom_fields(true)
    update_plugin_group_membership(domain)
    registered_plugins(domain)
  end

  add_to_class(:user, :registered_plugins) do |domain = nil|
    query = "user_id = #{self.id} AND name LIKE '%-#{user_key_suffix}'"
    query += " AND value LIKE '%#{domain}%'" if domain

    ::UserCustomField.where(query).map do |ucf|
      ::PluginManager::UserPlugin.new(ucf.name.split("-#{user_key_suffix}").first, ucf.value)
    end
  end

  add_to_class(:user, :registered_plugins_updated_at) do |domain = nil|
    query = "user_id = #{self.id}"

    if domain
      query += "AND name = '#{domain}-#{user_updated_at_key_suffix}'"
    else
      query += "AND name LIKE '%-#{user_updated_at_key_suffix}'"
    end

    records = ::UserCustomField.where(query)
    return records.first.value if domain.present?

    records.reduce({}) do |result, r|
      domain = r.name.split("-#{user_updated_at_key_suffix}").first
      result[domain] = r.value
      result
    end
  end

  add_to_class(:user, :update_plugin_group_membership) do |domain|
    registered_plugins(domain).each do |user_plugin|
      if plugin = PluginManager::Plugin.get(user_plugin.name)
        plugin.add_user(self)
      end
    end
  end

  add_user_api_key_scope(:plugin_user,
    methods: :post,
    actions: %w[
      plugin_manager/plugin_user#register
      plugin_manager/plugin_status#update
      plugin_manager/plugin_status#validate_key
    ],
    params: %i[plugins domain]
  )

  add_api_key_scope(:plugin_manager, {
    status: {
      actions: %w[
        plugin_manager/plugin_status#update
        plugin_manager/plugin_status#validate_key
      ],
      params: %i[plugins domain]
    }
  })

  if defined?(DiscourseCodeReview) == 'constant' && DiscourseCodeReview.class == Module
    DiscourseCodeReview::Hooks.add_parent_category_finder(:plugin_manager) do |repo_name, repo_id, issues|
      if issues && category = Category.find_by(slug: repo_name.split("/", 2).last)
        category.id
      else
        nil
      end
    end

    DiscourseCodeReview::Hooks.add_category_namer(:plugin_manager) do |repo_name, repo_id, issues|
      if issues
        "Issues"
      else
        nil
      end
    end
  end
end
