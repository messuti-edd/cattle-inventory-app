class Empleado < ActiveRecord::Base
  has_many :movimientos
end
