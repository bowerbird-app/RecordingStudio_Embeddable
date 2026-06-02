class Folder < ApplicationRecord
	recording_studio_recordable label: "Folder", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

	def self.recordable_type_label
		"Folder"
	end

	class << self
		alias_method :recording_studio_type_label, :recordable_type_label
	end

	def recordable_name
		name.to_s.squish.presence || self.class.recordable_type_label
	end

	alias_method :recording_studio_label, :recordable_name
end