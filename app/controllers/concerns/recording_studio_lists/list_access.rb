# frozen_string_literal: true

module RecordingStudioLists
  module ListAccess
    extend ActiveSupport::Concern
    include RecordingStudioAccessible::ControllerAuth

    included do
      recording_studio_auth(
        config: -> { RecordingStudioAccessible.configuration },
        prefix: :lists,
        authenticate: false,
        set_current_actor: false,
        missing_root_status: :not_found,
        forbidden_status: :not_found,
        response_style: lambda { |_status, _reason = nil|
          raise RecordingStudio::Lists::InvalidList
        }
      )
    end

    private

    def load_list!(role:)
      authorize_list!(RecordingStudio::Lists.find(params[:id]), role: role)
    end

    def authorize_list!(list, role:)
      raise RecordingStudio::Lists::InvalidList unless list
      raise RecordingStudio::Lists::InvalidList unless list.root_recording_id == parent_recording.id

      authorize_recording!(list, role: role)
      list
    end

    def require_parent_edit!
      authorize_recording!(parent_recording, role: :edit)
    end

    def lists_for(parent, minimum_role:)
      AccessibleLists.for(actor: lists_actor, parent: parent, minimum_role: minimum_role)
    end

    def run_membership
      yield load_list!(role: :edit)
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    rescue RecordingStudio::Lists::Error => e
      respond_membership_error(e)
    end

    def revise_submitted_list
      @list = load_list!(role: :edit)
      @name = list_params[:name]
      @description = list_params[:description]
      @return_to = safe_return_path
      RecordingStudio::Lists.update(@list, name: @name, description: @description, actor: lists_actor)
    end

    def build_list
      RecordingStudio::Lists.create(
        parent: parent_recording,
        name: list_params[:name],
        description: list_params[:description],
        idempotency_key: params[:idempotency_key],
        actor: lists_actor
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

    def assign_add_context
      @recording_id = params[:recording_id].presence
      @return_to = safe_return_path
    end

    def attach_recording(list)
      return if params[:recording_id].blank?

      RecordingStudio::Lists.add(list, params[:recording_id], actor: lists_actor)
    end
  end
end
