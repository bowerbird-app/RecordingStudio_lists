# frozen_string_literal: true

# Root switch v0.9.0 still constructs PageNav with anchor_url and anchor_label.
# Flatpack 0.1.274 removed those keywords. Translate them to with_close.
module DummyPageNavClose
  def initialize(*args, anchor_url: nil, anchor_label: nil, **kwargs)
    super(*args, **kwargs)
    return if anchor_url.blank?

    with_close(href: anchor_url, tooltip: anchor_label)
  end
end

Rails.application.config.to_prepare do
  component = FlatPack::PageNav::Component
  next if component.ancestors.include?(DummyPageNavClose)

  component.prepend(DummyPageNavClose)
end
