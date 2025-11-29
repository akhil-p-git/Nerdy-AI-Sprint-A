class CreateKnowledgeNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_nodes do |t|
      t.references :student, null: false, foreign_key: true
      t.string :source_type  # session, conversation, practice
      t.bigint :source_id
      t.string :subject
      t.string :topic
      t.text :content
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    # Add vector column using raw SQL since pgvector gem may not be fully Rails 8 compatible
    execute "ALTER TABLE knowledge_nodes ADD COLUMN embedding vector(1536)"

    # Add index for vector similarity search
    execute "CREATE INDEX ON knowledge_nodes USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)"
  end
end

