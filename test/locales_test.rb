# frozen_string_literal: true

require "test_helper"
require "yaml"
require "i18n"

class LocalesTest < Minitest::Test
  def setup
    @previous_load_path = I18n.load_path.dup
    @previous_backend = I18n.backend
    @previous_locale = I18n.locale
    I18n.backend = I18n::Backend::Simple.new
    I18n.backend.load_translations(*Dir[File.join(engine_locales_dir, "*.yml")])
    I18n.locale = :en
  end

  def teardown
    I18n.backend = @previous_backend
    I18n.locale = @previous_locale
    assert_equal @previous_load_path, I18n.load_path,
                 "locales tests must not mutate I18n.load_path"
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_rails_i18n_load_path_includes_the_gem_english_locale_file
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    existent = RecordingStudioEmbeddable::Engine.paths["config/locales"].existent.map do |path|
      File.expand_path(path)
    end

    assert_includes existent, locale_path
  end

  def test_lib_sources_do_not_append_i18n_load_path
    lib_root = File.expand_path("../lib", __dir__)
    ruby_files = Dir[File.join(lib_root, "**", "*.rb")]

    refute_empty ruby_files, "expected lib/**/*.rb files to scan"

    ruby_files.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path", "#{path} must not touch i18n.load_path"
      refute_includes source, "I18n.load_path", "#{path} must not touch I18n.load_path"
    end
  end

  def test_english_defaults_match_main_copy
    I18n.with_locale(:en) do
      assert_equal "Close", t("common.close")
      assert_equal "Embed", t("common.embed")
      assert_equal "Embed settings updated.", t("flashes.settings_updated")
      assert_equal "Embed styling updated.", t("flashes.styling_updated")
      assert_equal "Custom styling is disabled for this embed.", t("flashes.styling_disabled")
      assert_equal "Oops", t("public.oops")
      assert_equal(
        "This embed is gone, or the link is wrong. Check the address and try again.",
        t("public.not_found_description")
      )
      assert_equal "Last 7 days", t("management.stats.ranges.seven_days")
      assert_equal "Per day", t("management.stats.granularities.day")
      assert_equal "All views", t("management.stats.viewers.all")
      assert_equal "Week of Jan 5", t("management.stats.week_of", date: "Jan 5")
      assert_equal(
        "Invalid embedder domain: bad!",
        t("errors.invalid_embedder_domain", domain: "bad!")
      )
      assert_equal "Sans", t("management.fonts.sans")
    end
  end

  def test_install_help_describes_where_to_paste_the_code
    I18n.with_locale(:en) do
      embed_help = "Add this code to your website wherever you want this to appear, " \
                   "for example inside a page or blog post. " \
                   "Paste it into the page's HTML, or ask your web developer to add it."
      assert_equal embed_help, t("management.edit.embed_code_help")

      embed_platforms = "Using Squarespace, Wix or WordPress? " \
                        "Add an \"Embed\", \"HTML\" or \"Custom code\" block and paste the code into it."
      assert_equal embed_platforms, t("management.edit.embed_code_platforms")

      snippet_help = "Add this code to every page of your website where you want the Chat button to appear. " \
                     "Paste it just before the closing <code>&lt;/head&gt;</code> tag, " \
                     "or ask your web developer to add it."
      assert_equal snippet_help, t("management.floating.snippet_help_html", label: "Chat button")

      snippet_platforms = "Using Squarespace, Wix or WordPress? " \
                          "Look for a \"Header code injection\" or \"Custom code\" setting."
      assert_equal snippet_platforms, t("management.floating.snippet_platforms")
    end
  end

  def test_yes_no_on_off_locale_keys_resolve_without_default
    yes_no_keys = collect_yes_no_on_off_keys(
      locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
    )

    I18n.with_locale(:en) do
      yes_no_keys.each do |key|
        full_key = "recording_studio.embeddable.#{key}"
        translation = I18n.t(full_key)

        refute_equal "translation missing: en.#{full_key}", translation
        refute_includes translation.to_s, "translation missing"
      end
    end
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_embeddable.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_dummy_gemfile_does_not_depend_on_internationalization
    dummy_gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    refute_includes dummy_gemfile, "recording_studio_internationalization"
    refute_includes dummy_gemfile, "RecordingStudio_Internationalization"
  end

  private

  def t(key, **)
    I18n.t("recording_studio.embeddable.#{key}", **)
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, root_key)
    YAML.safe_load_file(path).fetch(root_key)
  end

  def flatten_keys(tree, prefix = nil)
    tree.flat_map do |key, value|
      path = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, path) : [path]
    end
  end

  def collect_yes_no_on_off_keys(tree, prefix = nil)
    tree.flat_map do |key, value|
      path = [prefix, key].compact.join(".")
      if value.is_a?(Hash)
        collect_yes_no_on_off_keys(value, path)
      elsif %w[yes no on off true false null].include?(key.to_s.downcase)
        [path]
      else
        []
      end
    end
  end
end
