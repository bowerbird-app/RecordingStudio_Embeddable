# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

viewer = User.find_or_create_by!(email: "viewer@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordable
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")
article = Article.find_or_create_by!(title: "Article Requires Publishable")
document = Document.find_or_create_by!(title: "Document Publishable Only")

Page.where(id: page.id).update_all(description: "Page description used by both publishable and embeddable rendering.")
Article.where(id: article.id).update_all(description: "Article description for embeddable behavior testing.")
Document.where(id: document.id).update_all(description: "Document description for publishable-only behavior testing.")

# Create the root recording
root_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(
  recordable: workspace,
  parent_recording_id: nil
)

folder_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: root_recording.id,
  recordable: folder
)

page_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: folder_recording.id,
  recordable: page
)
page_recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"]) if page_recording.respond_to?(:ensure_embed!)

article_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: folder_recording.id,
  recordable: article
)
article_recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"]) if
  article_recording.respond_to?(:ensure_embed!) && article_recording.embeddable?

document_recording = RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: folder_recording.id,
  recordable: document
)

# Grant root-level admin access to the admin user
Current.actor = user
access = RecordingStudio::Access.find_or_create_by!(actor: user, role: :admin)
RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: root_recording.id,
  recordable: access
)

# Grant root-level view access to the viewer user
Current.actor = viewer
viewer_access = RecordingStudio::Access.find_or_create_by!(actor: viewer, role: :view)
RecordingStudio::Recording.unscoped.find_or_create_by!(
  root_recording_id: root_recording.id,
  parent_recording_id: root_recording.id,
  recordable: viewer_access
)

puts "Seeded: admin@admin.com / Password"
puts "Seeded: viewer@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Article '#{article.title}' (embeddable requires publishable, no publishable configured)"
puts "Seeded: Document '#{document.title}' (publishable enabled, embeddable not configured)"
puts "Seeded: Page public embed at /recording_studio_embeddable/embeds/#{page_recording.embed&.token}" if page_recording.respond_to?(:embed)
puts "Seeded: Article public embed at /recording_studio_embeddable/embeds/#{article_recording.embed&.token}" if
  article_recording.respond_to?(:embed)
