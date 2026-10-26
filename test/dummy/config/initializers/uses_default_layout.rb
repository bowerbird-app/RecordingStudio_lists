# frozen_string_literal: true

# Orderable v0.3.1 and Trashable v0.11.0 still include this module.
# Recording Studio 6.1 removed it. Defining it here lets those engines
# eager-load in the dummy app. Lists and the host controller do not include it.
module RecordingStudio
  module UsesDefaultLayout
    extend ActiveSupport::Concern

    included do
      recording_studio_layout { nil }
    end
  end
end
