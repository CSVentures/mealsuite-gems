# frozen_string_literal: true

Yass::Engine.routes.draw do
  root 'data_seeding#index'

  # Data Seeding Interface
  get 'data_seeding', to: 'data_seeding#index', as: :data_seeding
  get 'data_seeding/status', to: 'data_seeding#status'
  post 'data_seeding/load_yaml', to: 'data_seeding#load_yaml'
  post 'data_seeding/load_yaml_raw', to: 'data_seeding#load_yaml_raw'
  post 'data_seeding/validate_yaml', to: 'data_seeding#validate_yaml'
  post 'data_seeding/validate_yaml_raw', to: 'data_seeding#validate_yaml_raw'
  get 'data_seeding/list_yaml_files', to: 'data_seeding#list_yaml_files'
  get 'data_seeding/get_yaml_file_content', to: 'data_seeding#get_yaml_file_content'
  post 'data_seeding/run_static_qa_data', to: 'data_seeding#run_static_qa_data'
  get 'data_seeding/backup_info', to: 'data_seeding#backup_info'
  post 'data_seeding/create_backup', to: 'data_seeding#create_backup'
  post 'data_seeding/restore_backup', to: 'data_seeding#restore_backup'

  # Seed Registry Interface
  resources :seed_registry, only: [:index, :show] do
    collection do
      get :stats
      delete :clean_orphaned
    end
  end
end