ActiveRecord::Schema[8.1].define(version: 1) do
  create_table :authors, force: :cascade do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :articles, force: :cascade do |t|
    t.references :author, null: false, foreign_key: true
    t.string :title, null: false
    t.text :body, null: false
    t.integer :score, null: false, default: 0
    t.boolean :published, null: false, default: false
    t.datetime :published_at
    t.timestamps
  end
  add_index :articles, %i[published id]

  create_table :comments, force: :cascade do |t|
    t.references :article, null: false, foreign_key: true
    t.text :body, null: false
    t.timestamps
  end
end
