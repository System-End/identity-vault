# frozen_string_literal: true

class CreateRevokedJtis < ActiveRecord::Migration[8.0]
  def change
    create_table :revoked_jtis do |t|
      t.string :jti, null: false
      t.datetime :revoked_at, null: false
      t.string :revoked_by
      t.string :reason
    end

    add_index :revoked_jtis, :jti, unique: true
    add_index :revoked_jtis, :revoked_at
  end
end
