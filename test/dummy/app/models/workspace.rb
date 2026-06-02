class Workspace < ApplicationRecord
	recording_studio_recordable label: "Workspace", root: true, allowed_parent_types: []

	def self.recordable_type_label
		"Workspace"
	end

	class << self
		alias_method :recording_studio_type_label, :recordable_type_label
	end

	def recordable_name
		name.to_s.squish.presence || self.class.recordable_type_label
	end

	alias_method :recording_studio_label, :recordable_name
end
