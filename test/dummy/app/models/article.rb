class Article < ApplicationRecord
  include RecordingStudio::Capabilities::Embeddable.to(
    renderer: "articles/embed",
    require_publishable: true
  )
end
