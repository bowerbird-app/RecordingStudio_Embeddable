# frozen_string_literal: true

class CreateWidgetInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :widget_inquiries, id: :uuid do |t|
      t.string :widget_token, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.text :message, null: false
      t.timestamps
    end
  end
end
