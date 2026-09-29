# frozen_string_literal: true

RecordingStudioLists::Engine.routes.draw do
  resources :lists, only: [:index, :new, :create, :show, :destroy] do
    member do
      post :items, action: :add_item
      delete "items/:recording_id", action: :remove_item, as: :item
    end
  end
end
