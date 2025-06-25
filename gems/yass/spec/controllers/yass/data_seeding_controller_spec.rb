# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yass::DataSeedingController, type: :controller do
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

  describe 'GET #list_yaml_files' do
    it 'returns JSON with files list' do
      get :list_yaml_files
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to have_key('files')
      expect(json['files']).to be_an(Array)
    end
  end

  describe 'GET #status' do
    it 'returns status information' do
      get :status
      expect(response).to be_successful
      json = JSON.parse(response.body)
      expect(json).to have_key('status')
      expect(json).to have_key('ready_for_use')
    end
  end
end