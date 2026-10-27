# frozen_string_literal: true

# Recording Studio API 0.5.5 admin HTML (and other sibling gems still on the
# pre-6.1 shell) passes style: to FlatPack::Card and calls
# recording_studio_page_nav. Flatpack 0.1.319 rejects that card keyword, and
# Recording Studio 6.1 removed the helper. These screens are not Publishable
# views, so Publishable 0.12.0 does not change them.
module DummyCardWithoutStyle
  def initialize(*args, **kwargs)
    kwargs.delete(:style)
    super(*args, **kwargs)
  end
end

module DummyRecordingStudioPageNav
  PAGE_NAV_SLOT_KEYS = %i[
    page_nav_anchor_url
    page_nav_anchor_label
    page_nav_back_url
    page_nav_back_label
  ].freeze

  def recording_studio_page_nav(title: nil, **options)
    content_for(:title, title) if title.present?

    PAGE_NAV_SLOT_KEYS.each do |slot_key|
      next unless options.key?(slot_key)

      value = options.fetch(slot_key)
      next if value.nil?

      content_for(slot_key, value)
    end

    nil
  end
end

Rails.application.config.to_prepare do
  card = FlatPack::Card::Component
  card.prepend(DummyCardWithoutStyle) unless card.ancestors.include?(DummyCardWithoutStyle)

  helper = RecordingStudio::LayoutHelper
  next if helper.method_defined?(:recording_studio_page_nav)
  next if helper.ancestors.include?(DummyRecordingStudioPageNav)

  helper.prepend(DummyRecordingStudioPageNav)
end
