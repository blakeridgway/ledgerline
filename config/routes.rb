Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resource :profile, only: %i[show edit update]

  resources :clients do
    member do
      get :timesheet
    end

    resources :time_entries, only: %i[index], shallow: true
  end

  resources :time_entries, except: %i[new show] do
    collection do
      get :batch
      post :batch, action: :save_batch, as: :save_batch
    end
  end

  resources :invoices do
    collection do
      post :draft_retainers
    end

    member do
      post :mark_paid
      post :mark_sent
      post :void
      post :repeat
      post :deliver
      post :remind
    end
  end

  resources :expenses, except: %i[show]

  get "reports", to: "reports#show", as: :reports

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#show"
end
