# frozen_string_literal: true

module RecordingStudioLists
  module MenuResponses
    ERROR_COPY_KEYS = {
      RecordingStudio::Lists::BlankName => "blank_name",
      RecordingStudio::Lists::InvalidList => "invalid_list",
      RecordingStudio::Lists::MissingTarget => "missing_target",
      RecordingStudio::Lists::DifferentRoot => "different_root",
      RecordingStudio::Lists::SelfTarget => "self_target",
      RecordingStudio::Lists::ListItemTarget => "list_item_target",
      RecordingStudio::Lists::ParentNotAllowed => "parent_not_allowed"
    }.freeze

    CHOOSE_PLACE_MESSAGE = "Choose a place for this list first."

    private

    def respond_created(list)
      return render json: menu_list_payload(list), status: :created if menu_request?

      redirect_to safe_return_path || list_path(list),
                  notice: Copy.t("flashes.created")
    end

    def respond_blank_name(error)
      return render json: { error: list_error_copy(error) }, status: :unprocessable_entity if menu_request?

      @name = list_params[:name]
      @description = list_params[:description]
      @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
      @name_error = Copy.t("errors.blank_name")
      assign_add_context
      render :new, status: :unprocessable_entity
    end

    def respond_blank_edit
      @name_error = Copy.t("errors.blank_name")
      render :edit, status: :unprocessable_entity
    end

    def respond_list_error(error)
      message = list_error_copy(error)
      return render json: { error: message }, status: :unprocessable_entity if menu_request?

      redirect_to safe_return_path || lists_path, alert: message
    end

    def respond_membership(list, notice)
      return head :no_content if menu_request?

      redirect_to safe_return_path || list_path(list), notice: notice
    end

    def respond_membership_error(error)
      return head :unprocessable_entity if menu_request?

      redirect_to safe_return_path || list_path(params[:id]), alert: list_error_copy(error)
    end

    def list_error_copy(error)
      if error.is_a?(RecordingStudio::Lists::ParentNotAllowed) &&
         error.message == CHOOSE_PLACE_MESSAGE
        return Copy.t("errors.choose_place")
      end

      key = ERROR_COPY_KEYS[error.class]
      return error.message unless key

      default_message = error.class.new.message
      return error.message unless error.message == default_message

      Copy.t("errors.#{key}")
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
    include ListAccess
    include MenuResponses

    def index
      @lists = lists_for(parent_recording, minimum_role: :view)
    rescue RecordingStudio::Lists::ParentNotAllowed => e
      @lists = []
      flash.now[:alert] = list_error_copy(e)
    end

    def new
      require_parent_edit!
      @idempotency_key = SecureRandom.uuid
      assign_add_context
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    end

    def create
      require_parent_edit!
      list = build_list
      attach_recording(list)
      respond_created(list)
    rescue RecordingStudio::Lists::BlankName => e
      respond_blank_name(e)
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    rescue RecordingStudio::Lists::Error => e
      respond_list_error(e)
    end

    def show
      @list = load_list!(role: :view)
      @items = RecordingStudio::Lists.items(@list)
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    end

    def add_item
      run_membership do |list|
        RecordingStudio::Lists.add(list, params[:recording_id], actor: lists_actor)
        respond_membership(list, Copy.t("flashes.added"))
      end
    end

    def remove_item
      run_membership do |list|
        RecordingStudio::Lists.remove(list, params[:recording_id])
        respond_membership(list, Copy.t("flashes.removed"))
      end
    end

    def edit
      @list = load_list!(role: :edit)
      @name = @list.name
      @description = @list.recordable.description
      @return_to = safe_return_path
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    end

    def update
      revise_submitted_list
      redirect_to @return_to || lists_path, notice: Copy.t("flashes.updated")
    rescue RecordingStudio::Lists::BlankName
      respond_blank_edit
    rescue RecordingStudio::Lists::InvalidList => e
      redirect_to lists_path, alert: list_error_copy(e)
    end

    def destroy
      RecordingStudio::Lists.delete(load_list!(role: :edit))
      redirect_to lists_path, notice: Copy.t("flashes.deleted")
    rescue RecordingStudio::Lists::InvalidList => e
      redirect_to lists_path, alert: list_error_copy(e)
    end
  end
end
