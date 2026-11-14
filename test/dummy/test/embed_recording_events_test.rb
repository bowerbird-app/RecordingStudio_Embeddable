# frozen_string_literal: true

require "test_helper"

class EmbedRecordingEventsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "embed-events-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    workspace = Workspace.create!(name: "Embed events #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    @page = @root.record(Page, actor: @user) { |page| page.title = "Event page" }
  end

  teardown do
    Current.actor = nil
    RecordingStudio.configuration.hooks.clear(:before_record)
    RecordingStudio.configuration.hooks.clear(:after_record)
  end

  test "ensure_embed! records a created event with the actor and runs record hooks" do
    before = []
    after = []
    RecordingStudio.configuration.hooks.before_record { |context| before << context }
    RecordingStudio.configuration.hooks.after_record { |event| after << event }

    embed = @page.ensure_embed!(actor: @user, enabled: false)
    child = @page.embed_child_recording

    assert_equal embed, child.recordable
    assert_equal @page.id, child.parent_recording_id
    created = events_for(child, "created")
    assert_equal 1, created.size
    assert_equal @user, created.first.actor
    assert_empty events_for(child, "embeddable.embed.created")

    assert before.any? { |context|
      context[:action] == "created" &&
        context[:actor] == @user &&
        context[:recordable].is_a?(RecordingStudioEmbeddable::Embed)
    }
    assert after.any? { |event|
      event.action == "created" && event.actor == @user && event.recording_id == child.id
    }

    assert_equal embed, @page.ensure_embed!(actor: @user)
    assert_equal 1, events_for(child, "created").size
  end

  test "update enable and disable log an updated event with the actor" do
    embed = @page.ensure_embed!(actor: @user)
    token = embed.token

    @page.update_embed!(actor: @user, allowed_embedder_domains: ["partner.example"])
    @page.enable_embed!(actor: @user)
    @page.disable_embed!(actor: @user)

    updated = events_for(@page.embed_child_recording, "embeddable.embed.updated")
    assert_equal 3, updated.size
    updated.each do |event|
      assert_equal @user, event.actor
      assert_equal embed.id, event.metadata.with_indifferent_access[:embed_id]
    end
    assert_equal token, embed.reload.token
    assert_equal embed.id, @page.embed.id
    assert_not embed.reload.enabled?
  end

  test "logging failures raise" do
    @page.ensure_embed!(actor: @user)
    Current.actor = nil

    error = assert_raises(RecordingStudio::ActorRequired) do
      @page.update_embed!(enabled: true)
    end

    assert_match(/actor is required/, error.message)
    assert_empty events_for(@page.embed_child_recording, "embeddable.embed.updated")
  end

  private

  def events_for(recording, action)
    RecordingStudio::Event.where(recording_id: recording.id, action: action).order(:created_at)
  end
end
