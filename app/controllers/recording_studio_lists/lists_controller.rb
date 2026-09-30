# frozen_string_literal: true

module RecordingStudioLists
  module MenuResponses
    private

    def respond_created(list)
      return render json: menu_list_payload(list), status: :created if menu_request?

      redirect_to safe_return_path || list_path(list), notice: "List created."
    end

    def respond_blank_name(error)
      return render json: { error: error.message }, status: :unprocessable_entity if menu_request?

      @name = list_params[:name]
      @description = list_params[:description]
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      @name_error = "Name can't be blank."
      assign_add_context
      render :new, status: :unprocessable_entity
    end

    def respond_list_error(error)
      return render json: { error: error.message }, status: :unprocessable_entity if menu_request?

      redirect_to safe_return_path || lists_path, alert: error.message
    end

    def respond_membership(list, notice)
      return head :no_content if menu_request?

      redirect_to safe_return_path || list_path(list), notice: notice
    end

    def respond_membership_error(error)
      return head :unprocessable_entity if menu_request?

      redirect_to safe_return_path || list_path(params[:id]), alert: error.message
    end

    def menu_list_payload(list)
      payload = { id: list.id, name: list.name.to_s }
      return payload if params[:recording_id].blank?

      payload.merge(
        add_url: items_list_path(list),
        remove_url: item_list_path(list, recording_id: params[:recording_id])
      )
    end

    def safe_return_path
      RecordingStudio::Lists::InternalPath.sanitize(params[:return_to])
    end

    def menu_request?
      request.headers["X-Lists-Menu"] == "1"
    end
  end

  class ListsController < ApplicationController
    include MenuResponses

    def index
      @lists = RecordingStudio::Lists.lists(parent_recording)
      @item_counts = item_counts_for(@lists)
    rescue RecordingStudio::Lists::ParentNotAllowed => e
      @lists = []
      @item_counts = {}
      flash.now[:alert] = e.message
    end

    def new
      @idempotency_key = SecureRandom.uuid
      assign_add_context
    end

    def create
      list = build_list
      attach_recording(list)
      respond_created(list)
    rescue RecordingStudio::Lists::BlankName => e
      respond_blank_name(e)
    rescue RecordingStudio::Lists::Error => e
      respond_list_error(e)
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
      respond_membership(list, "Added.")
    rescue RecordingStudio::Lists::Error => e
      respond_membership_error(e)
    end

    def remove_item
      list = RecordingStudio::Lists.find(params[:id])
      RecordingStudio::Lists.remove(list, params[:recording_id])
      respond_membership(list, "Removed.")
    rescue RecordingStudio::Lists::Error => e
      respond_membership_error(e)
    end

    def destroy
      RecordingStudio::Lists.delete(params[:id])
      redirect_to lists_path, notice: "List deleted."
    rescue RecordingStudio::Lists::InvalidList => e
      redirect_to lists_path, alert: e.message
    end

    private

    def build_list
      RecordingStudio::Lists.create(
        parent: parent_recording,
        name: list_params[:name],
        description: list_params[:description],
        idempotency_key: params[:idempotency_key],
        actor: current_actor
      )
    end

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
