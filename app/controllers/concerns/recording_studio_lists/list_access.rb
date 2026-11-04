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
      AccessibleLists.for(actor: current_actor, parent: parent, minimum_role: minimum_role)
    end

    def run_membership
      yield load_list!(role: :edit)
    rescue RecordingStudio::Lists::InvalidList
      head :not_found
    rescue RecordingStudio::Lists::Error => e
      respond_membership_error(e)
    end
  end
end
