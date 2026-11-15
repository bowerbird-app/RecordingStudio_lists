class HomeController < ApplicationController
  def index
    @featured_recording = featured_page_recording
  end

  private

  def featured_page_recording
    root = current_root_recording if respond_to?(:current_root_recording)
    return if root.blank?

    RecordingStudio::Recording
      .kept
      .where(root_recording_id: root.id, recordable_type: "Page")
      .order(:created_at, :id)
      .first
  end
end
