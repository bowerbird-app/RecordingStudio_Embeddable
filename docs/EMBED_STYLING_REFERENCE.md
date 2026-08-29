# Embed Styling Reference

Embed styling works in three layers:

1. The host app's FlatPack theme provides the baseline.
2. A recordable can declare `customizable_embed_styles` with code defaults.
3. Per-embed overrides from the management UI apply last.

## Recordable Schema

Declare customizable fields on the embeddable capability or macro options:

```ruby
include RecordingStudio::Capabilities::Embeddable.to(
  renderer: "pages/embed",
  customizable_embed_styles: {
    background_color: {
      label: "Background color",
      css_variable: "--surface-background-color",
      input: :color,
      default: "#ffffff"
    },
    font_family: {
      label: "Font",
      css_property: "font-family",
      input: :font_select
    },
    max_width: {
      label: "Max width",
      css_property: "max-width",
      input: :select,
      choices: [["Reading", "720px"], ["Wide", "1200px"]],
      default: "720px"
    }
  }
)
```

Supported field metadata:

- `label:` human-readable field label.
- `css_variable:` FlatPack CSS variable to override.
- `css_property:` Direct CSS property for layout-only values.
- `input:` `:color`, `:select`, `:font_select`, `:length`, `:text`, or `:integer`.
- `choices:` option list for `:select` fields.
- `default:` recordable-level default.

## Recommended FlatPack Variables

These variables map cleanly to embed customization and already fit the engine layouts and dummy examples:

- `--surface-background-color`
- `--surface-content-color`
- `--surface-muted-content-color`
- `--surface-border-color`
- `--color-primary`

These are useful supporting FlatPack variables when your embed templates need them:

- `--surface-page-background-color`
- `--surface-muted-background-color`
- `--surface-border-hover-color`
- `--color-primary-hover`
- `--color-primary-text`
- `--radius-sm`
- `--radius-md`
- `--radius-lg`
- `--radius-xl`
- `--stack-gap-sm`
- `--stack-gap-md`
- `--stack-gap-lg`

FlatPack's broader theming surface is documented in:

- `/usr/local/bundle/ruby/3.3.0/bundler/gems/flatpack-af4a11ec13ef/docs/theming.md`
- `/usr/local/bundle/ruby/3.3.0/bundler/gems/flatpack-af4a11ec13ef/docs/custom_theming.md`

## Direct CSS Properties

Use direct CSS properties for values that are layout decisions rather than FlatPack theme tokens:

- `font-family`
- `padding`
- `border-radius`
- `max-width`
- `min-height`

The engine's helper converts common token values automatically:

- `padding_scale`: `none`, `xs`, `sm`, `md`, `lg`, `xl`
- `radius_scale`: `none`, `sm`, `md`, `lg`, `xl`
- `font_family`: curated CSS stacks from FlatPack FontSwatch, legacy stack keys (`sans`, `serif`, `mono`), or a Google font name

## Host Theme Inheritance

If a recordable does not declare a field default and an embed does not override it, the helper writes nothing for that field. That keeps the host app's FlatPack theme in control.

## Management UI

### Style

Style owns fonts, colours, and embed width (not domains).

- Font, colour, and width share one FlatPack `OverflowRow` (`gap: :md`): `FontSwatch` first, then `ColorSwatch` circles, then a round FlatPack `Button` for width.
- The row never wraps. When swatches overflow, OverflowRow scrolls sideways with a hidden scrollbar and a soft trailing fade while more remains to the right (fade clears at the end).
- Colour names and the font name are tooltip-only (no label under the circle).
- Clicking a colour circle opens the native colour picker; clicking FontSwatch opens its FlatPack Popover menu (tooltip hides while open).
- Save posts ColorSwatch colour inputs and FontSwatch’s hidden `name` with the form (`embed[appearance][...]`).
- A live embed preview iframe sits below the swatch row (management preview). There is no separate Preview button on this screen.
- Width is a round FlatPack `Button` in the OverflowRow. It opens a FlatPack `Popover` with Auto (`100%` fill) and Custom. Custom reveals one full-width FlatPack `TextInput` for a typed CSS width. Height is always `auto` (no height field). Style save posts `embed[sizing][width]` and `embed[sizing][height]=auto`. The snippet and live preview use `style="width:…"` with `max-width: 100%`.
- Padding, radius, and other non-font fields are not shown on this screen.
- Save and Reset are separate FlatPack Buttons in one row (Save primary).
- Reset restores each ColorSwatch colour and the FontSwatch font to resolved/default values, resets width to Auto (`100%`), and refreshes the live preview.

### Settings

Settings owns allowed/blocked domains and Save. Width and height are not edited on Settings.

Require FlatPack `~> 0.1.143` (GitHub tag `v0.1.143`) for `FlatPack::ColorSwatch::Component`, `FlatPack::FontSwatch::Component`, `FlatPack::OverflowRow::Component`, `FlatPack::Button::Component`, and `FlatPack::Popover::Component`.

Example composition:

```erb
<%= render FlatPack::OverflowRow::Component.new(gap: :md) do %>
  <%= render FlatPack::FontSwatch::Component.new(
    font: current_css_family,
    options: [
      ["Sans", "ui-sans-serif, system-ui, sans-serif"],
      ["Serif", "ui-serif, Georgia, serif"],
      ["Mono", "ui-monospace, SFMono-Regular, monospace"]
    ],
    name: "embed[appearance][font_family]",
    text: "Sans",
    size: :lg
  ) %>
  <%= render FlatPack::ColorSwatch::Component.new(
    color: "#ffffff",
    text: "Background",
    name: "embed[appearance][background_color]",
    size: :lg
  ) %>
  <%= render FlatPack::Button::Component.new(
    icon: "arrows-right-left",
    icon_only: true,
    style: :secondary,
    size: :lg,
    type: "button",
    class: "rounded-full",
    id: "embed-width-trigger",
    aria: { label: "Width" }
  ) %>
<% end %>
```

## Practical Guidance

- Prefer FlatPack variables for colors and component-surface theming.
- Prefer direct CSS properties for width, height, padding, and font family.
- Keep defaults in code on the recordable declaration.
- Use per-embed overrides only for the fields that the recordable explicitly exposes.
