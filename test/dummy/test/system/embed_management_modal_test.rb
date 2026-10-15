# frozen_string_literal: true

require "application_system_test_case"

class EmbedManagementModalTest < ApplicationSystemTestCase
  setup do
    Rails.application.load_seed
    @user = User.find_by!(email: "admin@admin.com")
    @page = Page.find_by!(title: "Getting Started")
    @page_recording = RecordingStudio::Recording.unscoped.find_by!(recordable: @page)
    @page_embed = @page_recording.embed
    @widget = Widget.find_by!(title: "Hello")
    @widget_recording = RecordingStudio::Recording.unscoped.find_by!(recordable: @widget)
    @widget_embed = @widget_recording.embed
  end

  teardown do
    Current.actor = @user
    restore_page_embed
    restore_widget_embed
    Current.actor = nil
  end

  test "page embed modal keeps tab changes, validation, and save inside the window" do
    sign_in_and_open_modals
    click_button "Page embed"

    within_management_frame do
      assert_selector "h1", exact_text: "Embed style"
      assert_selector "[data-styling-form='true'][data-live-preview-bound='true']"
      click_on "Settings"
      assert_selector "h1", exact_text: "Embed settings"
      domains.fill_in with: "localhost"
      click_on "Save changes"
      assert_text "Invalid embedder domain: localhost"
      assert_text "Embed settings"
      domains.fill_in with: "example.com"
      click_on "Save changes"
      assert_text "Embed settings updated."
    end

    assert_current_path embed_modals_path
    within "[role=dialog]" do
      find(".flat-pack-modal__close button").click
    end
    assert_selector "##{RecordingStudioEmbeddable::MANAGEMENT_MODAL_ID}[aria-hidden='true']", visible: :all
  end

  test "chat button screen works inside the modal" do
    sign_in_and_open_modals
    click_button "Chat button"

    within_management_frame do
      assert_text "Show the Chat button"
      assert_selector "iframe#embed-floating-preview"
      assert_selector "[data-action*='copyFromButton']"
      choose "Bottom left"
    end

    within_frame "embed-floating-preview" do
      assert_selector "[data-recording-studio-widget][data-position='bottom-left']"
    end
    assert_current_path embed_modals_path
  end

  private

  def sign_in_and_open_modals
    visit new_user_session_path
    click_button "Sign In"
    assert_selector "h1", exact_text: "Dummy embeddables"
    visit embed_modals_path
    assert_selector "h1", exact_text: "Manage embeds"
  end

  def within_management_frame(&block)
    within "##{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}", &block
  end

  def domains
    find("textarea[name='embed[allowed_embedder_domains_text]']")
  end

  def restore_page_embed
    return unless @page_embed

    @page_embed.reload
    @page_embed.enabled = true
    @page_embed.allowed_embedder_domains = ["example.com"]
    @page_embed.persist_changes
  end

  def restore_widget_embed
    return unless @widget_embed

    @widget_embed.reload
    @widget_embed.floating_enabled = true
    @widget_embed.floating = { "position" => "bottom-right" }
    @widget_embed.persist_changes
  end
end
