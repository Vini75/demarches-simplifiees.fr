Flipper.configure do |config|
  config.default do
    Flipper.new(Flipper::Adapters::ActiveRecord.new)
  end
end

Flipper.register('Administrateurs') do |user|
  user.administrateur_id.present?
end
Flipper.register('Instructeurs') do |user|
  user.instructeur_id.present?
end

# This setup is primarily for first deployment, because consequently
# we can add new features from the Web UI. However when the new DB is created
# this will immediately migrate the default features to be controlled.
def setup_features(features)
  features.each do |feature|
    if !Flipper.exist?(feature)
      # Disable feature by default
      Flipper.disable(feature)
    end
  end
end

# A list of features to be deployed on first push
features = [
  :administrateur_champ_integer_number,
  :administrateur_graphql,
  :administrateur_web_hook,
  :insee_api_v3,
  :instructeur_bypass_email_login_token,
  :instructeur_download_as_zip,
  :maintenance_mode,
  :mini_profiler,
  :operation_log_serialize_subject,
  :pre_maintenance_mode,
  :xray
]

def database_exists?
  ActiveRecord::Base.connection
  true
rescue ActiveRecord::NoDatabaseError
  false
end

ActiveSupport.on_load(:active_record) do
  if database_exists? && ActiveRecord::Base.connection.data_source_exists?('flipper_features')
    setup_features(features)
  end
end
