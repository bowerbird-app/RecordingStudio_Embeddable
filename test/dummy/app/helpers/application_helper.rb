module ApplicationHelper
	def render_recording_tree_nodes(tree, nodes)
		nodes.each do |node|
			children = Array(node[:children])

			tree.node(label: node[:label], expanded: children.any?) do |child_tree|
				render_recording_tree_nodes(child_tree, children) if children.any?
			end
		end
	end
end
