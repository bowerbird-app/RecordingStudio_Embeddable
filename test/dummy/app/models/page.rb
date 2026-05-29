class Page < ApplicationRecord
  recording_studio_embeddable renderer: "pages/embed", require_publishable: false

  def published?
    true
  end
end