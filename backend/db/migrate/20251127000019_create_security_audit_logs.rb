class CreateSecurityAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :security_audit_logs do |t|
      t.string :audit_type, null: false
      t.jsonb :results, default: {}
      t.string :status
      t.timestamps
    end

    add_index :security_audit_logs, :created_at
    add_index :security_audit_logs, :status
  end
end


