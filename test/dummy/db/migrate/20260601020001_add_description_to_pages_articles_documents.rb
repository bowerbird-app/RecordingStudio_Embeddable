class AddDescriptionToPagesArticlesDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :description, :text
    add_column :articles, :description, :text
    add_column :documents, :description, :text
  end
end
