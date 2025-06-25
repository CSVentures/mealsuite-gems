# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yass::SeedRegistryController, type: :controller do
  routes { Yass::Engine.routes }

  describe 'GET #index' do
    it 'renders the index template' do
      get :index
      expect(response).to be_successful
      expect(response).to render_template(:index)
    end

    it 'responds with JSON format' do
      get :index, format: :json
      expect(response).to be_successful
      expect(response.content_type).to eq('application/json; charset=utf-8')
    end
  end

  describe 'GET #stats' do
    it 'returns statistics in JSON format' do
      get :stats, format: :json
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to have_key('total_entries')
      expect(json).to have_key('model_counts')
      expect(json).to have_key('orphaned_count')
    end
  end
end