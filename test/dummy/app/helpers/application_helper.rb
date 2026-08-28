module ApplicationHelper
	def render_recording_tree_nodes(tree, nodes)
		nodes.each do |node|
			children = Array(node[:children])

			tree.node(label: node[:label], expanded: children.any?) do |child_tree|
				render_recording_tree_nodes(child_tree, children) if children.any?
			end
		end
	end

	def dummy_recording_row_actions(recording, embed: nil)
		actions = []
		embed ||= recording.current_embed if recording.respond_to?(:current_embed)

		if embed.present?
			actions << {
				text: "Embed",
				href: recording_studio_embeddable.edit_management_embed_path(embed)
			}
		end

		edit_href = dummy_recordable_edit_path(recording.recordable)
		actions << { text: "Edit", href: edit_href } if edit_href.present?

		if respond_to?(:recording_studio_publishable) && recording.respond_to?(:current_publishable)
			actions << {
				text: dummy_publishable_action_label(recording),
				href: recording_studio_publishable.edit_recording_publishable_path(recording_id: recording.id)
			}
		end

		actions
	end

	def dummy_recordable_edit_path(recordable)
		case recordable
		when Page then edit_dummy_page_path(recordable)
		when Article then edit_dummy_article_path(recordable)
		when Document then edit_dummy_document_path(recordable)
		end
	end

	def dummy_publishable_action_label(recording)
		publishable = recording.current_publishable
		return "Edit" if publishable.blank?
		return "Scheduled" if publishable.respond_to?(:scheduled_for_future?) && publishable.scheduled_for_future?
		return "Published" if publishable.respond_to?(:published_state?) && publishable.published_state?
		return "Draft" if publishable.present?

		"Edit"
	end
end
