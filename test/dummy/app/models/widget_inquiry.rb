# frozen_string_literal: true

class WidgetInquiry < ApplicationRecord
  validates :widget_token, :name, :email, :message, presence: true
end
