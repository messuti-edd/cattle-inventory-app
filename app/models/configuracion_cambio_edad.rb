class ConfiguracionCambioEdad < ConfiguracionCambioAnimal
  default_scope where(tipo: "c_edad")
  after_create -> { self.tipo = "c_edad" }
end