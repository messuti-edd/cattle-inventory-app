class CreateGanadoGrupos < ActiveRecord::Migration
  def self.up
    create_table :ganado_grupos do |t|
      t.string :nombre

      t.timestamps
    end
  end

  def self.down
    drop_table :ganado_grupos
  end
end
