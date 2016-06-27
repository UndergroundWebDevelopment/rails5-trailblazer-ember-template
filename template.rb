git :init
git add: ".", commit: %(-m "Initial Commit")

# Install the trailblazer framework:
gem 'trailblazer', github: 'apotonick/trailblazer'
gem 'trailblazer-rails'

# Use the Puma server:
gem 'puma'

# Use active model serializers for JSONAPI formatted input & output:
gem 'active_model_serializers', '~> 0.10.0'

# Install the ember-cli-rails gem to allow for easy development of emberjs app(s)
# inline with the Rails backend:
gem "ember-cli-rails", github: 'thoughtbot/ember-cli-rails', branch: 'sd-rails-5'

# Install the knock gem for JSON web token support:
gem 'knock'

# Add bcrypt to gemfile for has_secure_password support:
gem 'bcrypt', '~> 3.1.7'

gem_group(:development, :test) do
  # Use rspec for unit tests (instead of Rails default testunit):
  gem 'rspec-rails'
	gem 'capybara'
end

# Set the version of ruby in the gemfile, to the currently running version of
# ruby. Ensures that everyone running the code uses the same version of ruby,
# and will set ruby for Heroku (if deploying there).
insert_into_file 'Gemfile', "ruby \"#{RUBY_VERSION}\"", after: "source 'https://rubygems.org'\n" 

# Create a procfile compatible with Heroku and/or Foreman:
file 'Procfile', <<-CODE
web: rails server Puma
CODE

# Add configuration for default URL options in test & development environments:
['development', 'test'].each do |env|
  environment env: env do
    <<-CODE
Rails.application.routes.default_url_options = {
  host: 'localhost',
  port: 3000
}
CODE
  end
end

# Generate an initializer for Active Model Serializers, telling them to use
# json_api format:
initializer 'active_model_serializers.rb', "ActiveModelSerializers.config.adapter = :json_api"

# Register a mime type handler for the json+api mime type:
append_to_file "config/initializers/mime_types.rb", 'Mime::Type.register "application/vnd.api+json", :json'

after_bundle do
  generate 'rspec:install'

  generate 'model user given_name:string surname:string email:string password_digets:string'
  generate 'knock:install'
  generate 'knock:token_controller user'

  insert_into_file "app/models/user.rb", "\thas_secure_password\n", after: "class User < ApplicationRecord\n"
  insert_into_file "app/controllers/application_controller.rb", "\tinclude Knock::Authenticable\n", after: "class ApplicationController < ActionController::API\n"

  # Generate an ember app named "frontend":
	run "ember new frontend --skip-git"

  # Generate initializer for ember-cli-rails:
  generate "ember:init"

  # Switch directories to the ember "frontend" app directory:
  inside('frontend') do
    # Install the ember-cli-rails-addon so that the ember app knows about
    # it's parent rails app:
    run "ember install ember-cli-rails-addon"
  end

  # Configure the rails router to mount the ember app at the root:
  insert_into_file "config/routes.rb", "\tmount_ember_app :frontend, to: \"/\"\n", after: "Rails.application.routes.draw do\n"

  # Install ember app dependencies (npm and bower deps):
  rake "ember:install"

  # Generate ember files to support deploying to Heroku:
  generate "ember:heroku"

  # Initial DB Creation & Migrations:
  rake "db:create", env: :development
  rake "db:migrate", env: :development

  # Commit changes from the template:
  git add: ".", commit: %(-m "After configuration by template.")
end
