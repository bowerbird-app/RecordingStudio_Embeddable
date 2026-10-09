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
# Recordables are immutable snapshots — prefer create / update_all over save!.
article = Article.find_by(title: "Spring release")
if article.blank?
  legacy_article = Article.find_by(title: "Article Requires Publishable")
  if legacy_article
    Article.where(id: legacy_article.id).update_all(title: "Spring release")
    article = Article.find(legacy_article.id)
  else
    article = Article.create!(title: "Spring release")
  end
end
document = Document.find_by(title: "Workspace notes")
if document.blank?
  legacy_document = Document.find_by(title: "Document Publishable Only")
  if legacy_document
    Document.where(id: legacy_document.id).update_all(title: "Workspace notes")
    document = Document.find(legacy_document.id)
  else
    document = Document.create!(title: "Workspace notes")
  end
end

Page.where(id: page.id).update_all(description: "Walk through workspace setup, embed codes, and how guests see a published page.")
Article.where(id: article.id).update_all(description: "What changed in the spring workspace release, including embed codes and guest publish flow.")
Document.where(id: document.id).update_all(description: "Brand colors, type, and asset rules for published pages.")

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

# First admin on an empty owned root must bootstrap — grant_access alone fails
# with "Not authorized to manage access" when nobody can manage yet.
unless RecordingStudioAccessible.authorized?(actor: user, recording: root_recording, role: :admin)
  bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(
    recording: root_recording,
    actor: user
  )
  raise bootstrap.error unless bootstrap.success?
end

# Further invites use grant_access with the bootstrapped admin as manager.
unless RecordingStudioAccessible.authorized?(actor: viewer, recording: root_recording, role: :view)
  viewer_grant = RecordingStudioAccessible.grant_access(
    recording: root_recording,
    actor: viewer,
    role: :view,
    manager_actor: user
  )
  raise viewer_grant.error unless viewer_grant.success?
end

# Publish Getting Started + Spring release so dedicated public embed paths render
# (Embeddable require_publishable). After Accessible bootstrap so publish is authorized.
if page_recording.respond_to?(:currently_published?) && !page_recording.currently_published?
  RecordingStudioPublishable::Services::Publishables::Update.call(
    parent_recording: page_recording,
    actor: user,
    attributes: { slug: "getting-started", status: "published" }
  )
end

if article_recording.respond_to?(:currently_published?) && !article_recording.currently_published?
  RecordingStudioPublishable::Services::Publishables::Update.call(
    parent_recording: article_recording,
    actor: user,
    attributes: { slug: "spring-release", status: "published" }
  )
end

# Cover + gallery images on every embeddable example (Page + Article).
# Attachable APIs only. Runs after Accessible grants so upload authorization succeeds.
press_kit = [
  {
    file: "kiln-canister-hero.jpg",
    name: "Kiln canister",
    caption: "Hero, three-quarter",
    credit: "Studio North",
    alt_text: "Smoked glass canister with a brass lid on pale limestone"
  },
  {
    file: "kiln-canister-open.jpg",
    name: "Kiln canister, open",
    caption: "Lid set aside",
    credit: "Studio North",
    alt_text: "Smoked glass canister with the brass lid resting beside it"
  },
  {
    file: "kiln-canister-detail.jpg",
    name: "Kiln canister, detail",
    caption: "Brass lid",
    credit: "Studio North",
    alt_text: "Close view of the brass lid on the smoked glass canister"
  },
  {
    file: "kiln-canister-table.jpg",
    name: "Kiln canister, table",
    caption: "On the breakfast table",
    credit: "Studio North",
    alt_text: "Smoked glass canister on a linen table beside a cup and napkin"
  }
]
press_kit_dir = Rails.root.join("db/seed_images")
press_kit.each do |shot|
  path = press_kit_dir.join(shot[:file])
  raise "Missing seed image fixture: #{path}" unless path.file?
end

seed_blob_available = lambda do |recording|
  attachment = recording&.recordable
  next false unless attachment&.file&.attached?

  blob = attachment.file.blob
  blob.service.exist?(blob.key)
rescue StandardError
  false
end

seed_press_kit_on = lambda do |parent_recording|
  existing_images = parent_recording.images(per_page: 100).to_a
  press_kit.each do |shot|
    existing = existing_images.find { |recording| recording.recordable.original_filename == shot[:file] }
    next if existing && seed_blob_available.call(existing)

    existing&.remove_attachment(actor: user)

    image_recording = File.open(press_kit_dir.join(shot[:file]), "rb") do |io|
      parent_recording.import_attachment(
        io: io,
        filename: shot[:file],
        content_type: "image/jpeg",
        name: shot[:name],
        actor: user,
        source: "press_kit"
      )
    end
    raise "Could not import #{shot[:file]} onto #{parent_recording.id}" if image_recording.nil?
    raise "Imported #{shot[:file]} but blob is missing" unless seed_blob_available.call(image_recording)

    image_recording.revise_attachment_metadata(
      actor: user,
      caption: shot[:caption],
      credit: shot[:credit],
      alt_text: shot[:alt_text]
    )

    RecordingStudioAttachable::PreprocessVariantsJob.perform_now(image_recording.recordable.id)
  end
end

seed_press_kit_on.call(page_recording)
seed_press_kit_on.call(article_recording)

puts "Seeded: admin@admin.com / Password"
puts "Seeded: viewer@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
puts "Seeded: Article '#{article.title}' (embeddable + publishable + Attachable)"
puts "Seeded: Document '#{document.title}' (publishable enabled, embeddable not configured)"
puts "Seeded: Page public embed at /recording_studio_embeddable/embeds/#{page_recording.embed&.token}" if page_recording.respond_to?(:embed)
puts "Seeded: Article public embed at /recording_studio_embeddable/embeds/#{article_recording.embed&.token}" if
  article_recording.respond_to?(:embed)
puts "Seeded: Page + Article press kits (#{press_kit.size} images each) with Attachable direct URLs"
