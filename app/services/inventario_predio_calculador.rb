class InventarioPredioCalculador
  def initialize(inventario_predio)
    @inventario_predio = inventario_predio
    @inventario        = inventario_predio.inventario
    @predio            = inventario_predio.predio
    @recuento          = last_recuento
    @fecha_inicio      = @recuento ? @recuento.fecha.advance(days: 1) : @inventario.gestion.desde
  end

  def calculate_ingr_egr_ganado_predio
    mov = Movimiento.joins(:ganados, :movimientos_tipo)
      .select("movimientos_tipos.id as movimiento_tipo_id, ganados.id as ganado_id, sum(movimiento_ganados.cant) as sumatoria")
      .where("movimientos_tipos.tipo in ('i', 'e') and movimientos.predio_id = ? and gestion_id = ?", 
        @predio.id, @inventario.gestion.id) 
      .group("movimientos_tipos.id, ganados.id")
      .order("movimientos_tipos.tipo asc")

    mov = mov.where("fecha >= ?", @fecha_inicio) if @recuento

    mov.each do |ingr_egr|
      inv_predio_ingr_egr = @inventario_predio.inventario_predio_ingr_egrs
        .find_or_create_by_movimientos_tipo_id(ingr_egr.movimiento_tipo_id)

      ganado = inv_predio_ingr_egr.inventario_predio_ingr_egr_ganados
        .find_or_initialize_by_ganado_id(ingr_egr.ganado_id)

      # actualizar inventario por predio, ingr/egr, por ganado
      ganado.update_attributes(cant: ingr_egr.sumatoria)
    end

    inv_ingr_egr = @inventario_predio.inventario_predio_ingr_egrs

    inv_ingr_egr.each do |ingr_egr|
      # actualizar inventario por predio, ingr/egr
      ingr_egr.cant = ingr_egr.inventario_predio_ingr_egr_ganados.sum(&:cant)
      ingr_egr.save
    end
  end

  def calculate_mov_ganado_predio(inv_predio_sec)
    # salida a otros predios
    mov_egr = Movimiento.joins(:ganados, :movimientos_tipo)
      .select("ganados.id as ganado_id, sum(movimiento_ganados.cant) as cant, sum(movimiento_ganados.cant_sec) as cant_sec, sum(movimiento_ganados.cant)-sum(movimiento_ganados.cant_sec) as perdidos, movimientos.predio_id, movimientos.predio_sec_id")
      .where("movimientos_tipos.tipo in ('m') and movimientos.predio_id = ? and movimientos.predio_sec_id = ? and gestion_id = ?", 
        @predio.id, inv_predio_sec.predio_id, @inventario.gestion.id)
      .group("movimientos.predio_id, movimientos.predio_sec_id, ganados.id")

    mov_egr = mov_egr.where("fecha >= ?", @fecha_inicio) if @recuento

    # entrada de otros predios
    mov_ingr = Movimiento.joins(:ganados, :movimientos_tipo)
      .select("ganados.id as ganado_id, sum(movimiento_ganados.cant) as cant, sum(movimiento_ganados.cant_sec) as cant_sec, sum(movimiento_ganados.cant)-sum(movimiento_ganados.cant_sec) as perdidos, movimientos.predio_id, movimientos.predio_sec_id ")
      .where("movimientos_tipos.tipo in ('m') and movimientos.predio_id = ? and movimientos.predio_sec_id = ? and gestion_id = ?", 
        inv_predio_sec.predio_id, @predio.id, @inventario.gestion.id)
      .group("movimientos.predio_sec_id , movimientos.predio_id, ganados.id")

    mov_ingr = mov_ingr.where("fecha >= ?", @fecha_inicio) if @recuento

    mov_egr.each do |mov|
      # es un egreso para el predio actual
      inv_predio_mov = @inventario_predio.inventario_predio_movs
        .find_or_create_by_tipo_and_predio_sec_id("egr", mov.predio_sec_id)

      ganado = inv_predio_mov.inventario_predio_mov_ganados
        .find_or_initialize_by_ganado_id(mov.ganado_id)

      ganado.update_attributes(cant: mov.cant, perdidos: mov.perdidos)

      # es un ingreso para el otro predio
      inv_predio_mov = inv_predio_sec.inventario_predio_movs
        .find_or_create_by_tipo_and_predio_sec_id("ingr", mov.predio_id)

      ganado = inv_predio_mov.inventario_predio_mov_ganados
        .find_or_initialize_by_ganado_id(mov.ganado_id)

      ganado.update_attributes(cant: mov.cant_sec, perdidos: mov.perdidos)
    end

    mov_ingr.each do |mov|
      # es un ingreso para el predio actual
      inv_predio_mov = @inventario_predio.inventario_predio_movs
        .find_or_create_by_tipo_and_predio_sec_id("ingr", mov.predio_id)

      ganado = inv_predio_mov.inventario_predio_mov_ganados
        .find_or_initialize_by_ganado_id(mov.ganado_id)

      ganado.update_attributes(cant: mov.cant_sec, perdidos: mov.perdidos)

      # es un egreso para el otro predio
      inv_predio_mov = inv_predio_sec.inventario_predio_movs
        .find_or_create_by_tipo_and_predio_sec_id("egr", mov.predio_sec_id)

      ganado = inv_predio_mov.inventario_predio_mov_ganados
        .find_or_initialize_by_ganado_id(mov.ganado_id)

      ganado.update_attributes(cant: mov.cant, perdidos: mov.perdidos)
    end
  end

  def calculate_totals
    # calcular inventario por predio por ganado
    saldos_mes_actual = Movimiento.joins(:ganados, :movimientos_tipo)
      .select("ganados.id as ganado_id, "+
        "sum(case when movimientos_tipos.tipo='e' then -1*movimiento_ganados.cant else movimiento_ganados.cant end) as sumatoria")
      .where("movimientos_tipos.tipo in ('i', 'e') and movimientos.predio_id = ? and gestion_id = ?", 
         @predio.id, @inventario.gestion.id)
      .group("ganados.id")

    saldos_mes_actual = saldos_mes_actual.where("fecha >= ?", @fecha_inicio) if @recuento

    missing = Ganado.where("id not in (?)", saldos_mes_actual.map(&:ganado_id).push(0))
      .select("id as ganado_id, 0 as sumatoria")

    movimientos = @inventario_predio.inventario_predio_movs.includes(:inventario_predio_mov_ganados)

    saldos_mes_actual += missing

    saldos_mes_actual.each do |ganado|
      # sumatoria de movimientos de esta gestion 
      # o despues del ultimo recuento de esta gestion si lo hubo
      cant = ganado.sumatoria.to_i 

      if @recuento.nil? # si no hubo un recuento esta gestion, tomar en cuenta la anterior gestion
        if @inventario.gestion.anterior
          inv = @inventario.gestion.anterior.get_inventario.get_inventario_predio(@predio.id)
          inv_ganado = inv.inventario_predio_ganados.find_by_ganado_id(ganado.ganado_id)
          cant += inv_ganado.cant if inv_ganado
        end
      else
        # si hubo un recuento esta gestion, se ignoran las gestiones anteriores, 
        # y se suma el recuento a los movimientos realizados despues del mismo
        cant += @recuento.movimiento_ganados.find_by_ganado_id(ganado.ganado_id).cant
      end

      # sumar los ingresos recividos por movimientos desde otros predios
      cant += movimientos.select {|m| m.tipo == "ingr"}.inject(0) do |sum, m|
        g = (m.inventario_predio_mov_ganados.select {|g| g.ganado_id == ganado.ganado_id.to_i}).first
        sum + (g ? g.cant : 0)
      end

      # restar los egresos de ganado enviado a otros predios
      cant -= movimientos.select {|m| m.tipo == "egr"}.inject(0) do |sum, m|
        g = m.inventario_predio_mov_ganados.select {|g| g.ganado_id == ganado.ganado_id.to_i}.first
        sum + (g ? g.cant : 0)
      end

      @inventario_predio.inventario_predio_ganados
        .find_or_create_by_ganado_id(ganado.ganado_id)
        .update_attributes(cant: cant)
    end
    
    # calcular inventario por predio
    @inventario_predio.update_attributes(cant: @inventario_predio.inventario_predio_ganados.sum(&:cant))

    # calcular inventario total
    @inventario.update_attributes(cant: @inventario.inventario_predios.sum(&:cant))
  end

  private

  def last_recuento
    mov = Movimiento.joins(:ganados, :movimientos_tipo)
      .where("fecha >= ? and fecha <= ? and movimientos_tipos.tipo='r' and predio_id = ?", 
        @inventario.gestion.desde, @inventario.gestion.hasta, @predio.id)
      .order("fecha desc").first
    return mov
  end
end