# frozen_string_literal: true

class CreateSigningKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :signing_keys do |t|
      t.string :kid, null: false
      t.text :private_key_seed_ciphertext, null: false
      t.jsonb :public_jwk, null: false, default: {}
      t.boolean :active, null: false, default: false
      t.datetime :retired_at

      t.timestamps
    end

    add_index :signing_keys, :kid, unique: true
    add_index :signing_keys, :active
    add_index :signing_keys, :retired_at
  end
end
