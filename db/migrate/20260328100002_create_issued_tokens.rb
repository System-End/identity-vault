# frozen_string_literal: true

class CreateIssuedTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :issued_tokens do |t|
      t.string :jti, null: false
      t.string :sub, null: false
      t.string :aud, null: false
      t.string :azp, null: false
      t.string :scope, null: false
      t.datetime :expires_at, null: false

      t.datetime :created_at, null: false
    end

    add_index :issued_tokens, :jti, unique: true
    add_index :issued_tokens, :expires_at
    add_index :issued_tokens, :sub
  end
end
