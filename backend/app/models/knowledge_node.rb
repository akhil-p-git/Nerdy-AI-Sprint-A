class KnowledgeNode < ApplicationRecord
  belongs_to :student
  belongs_to :source, polymorphic: true, optional: true

  validates :content, presence: true
  validates :embedding, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_subject, ->(subject) { where(subject: subject) }
  scope :by_topic, ->(topic) { where("topic ILIKE ?", "%#{topic}%") }

  # Find similar nodes using cosine similarity
  def similar_nodes(limit: 5)
    return [] unless embedding.present?

    KnowledgeNode
      .where(student_id: student_id)
      .where.not(id: id)
      .select("*, (embedding <=> '#{embedding}') as distance")
      .order(Arel.sql("embedding <=> '#{embedding}'"))
      .limit(limit)
  end
end
