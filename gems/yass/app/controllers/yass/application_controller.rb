# frozen_string_literal: true

module Yass
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'yass/application'

    before_action :restrict_to_development_environments

    private

    def restrict_to_development_environments
      unless Rails.env.development? || Rails.env.test?
        render plain: 'YASS interface is only available in development and test environments', status: :forbidden
      end
    end

    # Override page_without_user? to always return true for YASS pages
    # This bypasses the main application's authentication system
    def page_without_user?
      true
    end
  end
end