# frozen_string_literal: true

module RecordingStudioEmbeddable
  class StylingProfile < ApplicationRecord
    self.table_name = "recording_studio_embeddable_styling_profiles"

    validates :recordable_type, presence: true, uniqueness: true

    def defaults
      (self[:defaults] || {}).with_indifferent_access
    end

    def defaults=(value)
      self[:defaults] = (value || {}).to_h
    end
  end
end