# frozen_string_literal: true

require "application_system_test_case"

class FloatingWidgetTest < ApplicationSystemTestCase
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    Current.actor = @user
    workspace = Workspace.create!(name: "System #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @right = root.record(Widget, actor: @user) { |widget| widget.title = "Right chat" }
    @right_embed = @right.ensure_embed!(
      floating_enabled: true,
      floating: { "position" => "bottom-right" }
    )
    @left = root.record(Widget, actor: @user) { |widget| widget.title = "Left chat" }
    @left_embed = @left.ensure_embed!(
      floating_enabled: true,
      floating: { "position" => "bottom-left" }
    )
  end

  teardown { Current.actor = nil }

  def visit_installed(token)
    page.current_window.resize_to(1400, 900)
    port = Capybara.current_session.server.port
    visit "http://partner.example.test:#{port}#{widget_installed_path(token: token, script_host: "www.example.test:#{port}")}"
  end

  test "desktop launcher opens, escape closes, and focus returns" do
    page.current_window.resize_to(1400, 900)
    visit widget_on_site_path(tokens: @right_embed.token)

    launcher = find("[data-widget-launcher]")
    assert_equal "panel", find("[data-recording-studio-widget]")["data-layout"]
    assert_equal "bottom-right", find("[data-recording-studio-widget]")["data-position"]
    launcher.click

    assert_selector "[data-recording-studio-widget][data-open='true']"
    frame = find("[data-recording-studio-widget-frame]")
    assert_includes frame["src"], "/widgets/#{@right_embed.token}"
    within_frame(frame) do
      assert_text "Name"
      assert_button "Send"
    end

    page.send_keys :escape
    assert_no_selector "[data-recording-studio-widget][data-open='true']"
    assert page.evaluate_script("document.activeElement && document.activeElement.hasAttribute('data-widget-launcher')")
  end

  test "mobile popup is fullscreen" do
    page.current_window.resize_to(390, 844)
    visit widget_on_site_path(tokens: @right_embed.token)
    find("[data-widget-launcher]").click

    widget = find("[data-recording-studio-widget][data-open='true']")
    assert_equal "fullscreen", widget["data-layout"]
    assert_equal "bottom-right", widget["data-position"]
  end

  test "two tokens do not share open state" do
    page.current_window.resize_to(1400, 900)
    visit widget_on_site_path(tokens: "#{@right_embed.token},#{@left_embed.token}")

    assert_selector "[data-widget-launcher]", count: 2
    buttons = all("[data-widget-launcher]")
    buttons[0].click
    buttons[1].click
    assert_selector "[data-recording-studio-widget][data-open='true']", count: 2
    assert_selector "[data-position='bottom-right'][data-open='true']"
    assert_selector "[data-position='bottom-left'][data-open='true']"

    page.send_keys :escape
    assert_selector "[data-recording-studio-widget][data-open='true']", count: 1
    assert_selector "[data-position='bottom-right'][data-open='true']"
  end

  test "popup iframe keeps the built-in sandbox and has no allow attribute" do
    page.current_window.resize_to(1400, 900)
    visit widget_on_site_path(tokens: @right_embed.token)
    find("[data-widget-launcher]").click

    attributes = popup_iframe_attributes
    assert_equal "allow-scripts allow-forms allow-same-origin", attributes.fetch("sandbox")
    assert_nil attributes.fetch("allow")
  end

  test "floating_defaults sandbox and allow render on the popup iframe" do
    previous = RecordingStudioEmbeddable.configuration.floating_defaults
    RecordingStudioEmbeddable.configuration.floating_defaults = previous.merge(
      "sandbox" => "allow-scripts allow-forms allow-popups",
      "allow" => "clipboard-write"
    )
    page.current_window.resize_to(1400, 900)
    visit widget_on_site_path(tokens: @right_embed.token)
    find("[data-widget-launcher]").click

    attributes = popup_iframe_attributes
    assert_equal "allow-scripts allow-forms allow-popups", attributes.fetch("sandbox")
    assert_equal "clipboard-write", attributes.fetch("allow")
  ensure
    RecordingStudioEmbeddable.configuration.floating_defaults = previous if previous
  end

  test "opt-in sandbox and allow render on the popup iframe" do
    page.current_window.resize_to(1400, 900)
    visit widget_on_site_path(tokens: @right_embed.token)
    page.execute_script(<<~JS)
      var existing = document.querySelector("script[data-config]");
      var current = JSON.parse(existing.getAttribute("data-config"));
      var config = {
        id: "chatkit-frame",
        title: current.title,
        position: current.position,
        popup_url: current.popup_url,
        colors: current.colors,
        sandbox: "allow-scripts allow-same-origin allow-forms allow-popups",
        allow: "clipboard-write"
      };
      var extra = document.createElement("script");
      extra.src = existing.src;
      extra.async = true;
      extra.setAttribute("data-embed", config.id);
      extra.setAttribute("data-config", JSON.stringify(config));
      document.body.appendChild(extra);
      window.__recordingStudioFloatingWidget.scan();
    JS

    find("[data-recording-studio-widget='chatkit-frame'] [data-widget-launcher]").click
    attributes = popup_iframe_attributes("chatkit-frame")
    assert_equal "allow-scripts allow-same-origin allow-forms allow-popups", attributes.fetch("sandbox")
    assert_equal "clipboard-write", attributes.fetch("allow")

    original = popup_iframe_attributes(@right_embed.token)
    assert_equal "allow-scripts allow-forms allow-same-origin", original.fetch("sandbox")
    assert_nil original.fetch("allow")
  end

  test "installed snippet mounts a launcher from the endpoint" do
    visit_installed(@left_embed.token)

    assert_text "Partner site"
    assert_selector "[data-widget-launcher]", wait: 5
    widget = find("[data-recording-studio-widget]")
    assert_equal "bottom-left", widget["data-position"]
    assert_equal @left_embed.token, widget["data-recording-studio-widget"]
  end

  private

  def popup_iframe_attributes(widget_id = nil)
    selector = if widget_id
      "[data-recording-studio-widget='#{widget_id}'] [data-recording-studio-widget-frame]"
    else
      "[data-recording-studio-widget-frame]"
    end
    page.evaluate_script(<<~JS)
      (function () {
        var frame = document.querySelector(#{selector.to_json});
        return {
          sandbox: frame.getAttribute("sandbox"),
          allow: frame.getAttribute("allow")
        };
      })()
    JS
  end
end
