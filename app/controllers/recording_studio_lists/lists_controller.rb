# frozen_string_literal: true

module RecordingStudioLists
  class ListsController < ApplicationController
    def index
      @lists = RecordingStudio::Lists.lists(parent_recording)
      @item_counts = item_counts_for(@lists)
    rescue RecordingStudio::Lists::ParentNotAllowed => error
      @lists = []
      @item_counts = {}
      flash.now[:alert] = error.message
    end

    def new
      @idempotency_key = SecureRandom.uuid
      assign_add_context
    end

    def create
      list = RecordingStudio::Lists.create(
        parent: parent_recording,
        name: list_params[:name],
        description: list_params[:description],
        idempotency_key: params[:idempotency_key],
        actor: current_actor
      )
      attach_recording(list)
      redirect_to safe_return_path || list_path(list), notice: "List created."
    rescue RecordingStudio::Lists::BlankName
      @name = list_params[:name]
      @description = list_params[:description]
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      @name_error = "Name can't be blank."
      assign_add_context
      render :new, status: :unprocessable_entity
    rescue RecordingStudio::Lists::Error => error
      redirect_to safe_return_path || lists_path, alert: error.message
    end

    def show
      @list = RecordingStudio::Lists.find(params[:id])
      @items = RecordingStudio::Lists.items(@list)
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    end

    def add_item
      list = RecordingStudio::Lists.find(params[:id])
      RecordingStudio::Lists.add(list, params[:recording_id], actor: current_actor)
      redirect_to safe_return_path || list_path(list), notice: "Added."
    rescue RecordingStudio::Lists::Error => error
      redirect_to safe_return_path || list_path(params[:id]), alert: error.message
    end

    def remove_item
      list = RecordingStudio::Lists.find(params[:id])
      RecordingStudio::Lists.remove(list, params[:recording_id])
      redirect_to list_path(list), notice: "Removed."
    rescue RecordingStudio::Lists::Error => error
      redirect_to list_path(params[:id]), alert: error.message
    end

    def destroy
      RecordingStudio::Lists.delete(params[:id])
      redirect_to lists_path, notice: "List deleted."
    rescue RecordingStudio::Lists::InvalidList => error
      redirect_to lists_path, alert: error.message
    end

    private

    def parent_recording
      recording = current_root_recording if respond_to?(:current_root_recording)
      raise RecordingStudio::Lists::ParentNotAllowed, "Choose a place for this list first." if recording.blank?

      recording
    end

    def list_params
      params.fetch(:list, ActionController::Parameters.new).permit(:name, :description)
    end

    def current_actor
      Current.actor if defined?(Current)
    end

    def assign_add_context
      @recording_id = params[:recording_id].presence
      @return_to = safe_return_path
    end

    def attach_recording(list)
      return if params[:recording_id].blank?

      RecordingStudio::Lists.add(list, params[:recording_id], actor: current_actor)
    end

    def safe_return_path
      RecordingStudio::Lists::InternalPath.sanitize(params[:return_to])
    end

    def item_counts_for(lists)
      ids = lists.map(&:id)
      return {} if ids.empty?

      RecordingStudio::Recording
        .where(parent_recording_id: ids, recordable_type: RecordingStudio::Lists::ITEM_TYPE)
        .group(:parent_recording_id)
        .count
        .transform_keys(&:to_s)
    end
  end
end
