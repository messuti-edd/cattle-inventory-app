# encoding: UTF-8

require "spec_helper"

describe Movimiento do
  before { Timecop.freeze Time.now.advance(months: -1).change(day: 1) }
  let!(:gestion_anterior) { Fabricate :anterior, estado: 'A' }
  let(:san_vicente) { Fabricate :san_vicente }
  let(:camba_muerto) { Fabricate :camba_muerto }
  let(:compra) { Fabricate :compra }
  let(:venta) { Fabricate :venta }
  let(:tipo_movimiento) { Fabricate :tipo_movimiento }
  let!(:ganado_grupo) { Fabricate :ganado_grupo }
  let(:ganados) { ganado_grupo.ganados }
  let(:inventario_predio) { InventarioPredio.get_inventario(san_vicente.id) }

  context "Cuando el usuario registra ingresos/egresos de ganado" do
    before do

      Fabricate(:ingreso, predio: san_vicente, movimientos_tipo: compra,
        movimiento_ganados: [
        Fabricate(:movimiento_ganado, cant: 10, ganado: ganados.first),
        Fabricate(:movimiento_ganado, cant: 40, ganado: ganados.second)
      ])

      Fabricate(:ingreso, predio: san_vicente, movimientos_tipo: compra, 
        movimiento_ganados: [
        Fabricate(:movimiento_ganado, cant: 50, ganado: ganados.first)
      ])

      Fabricate(:egreso, predio: san_vicente, movimientos_tipo: venta, 
        movimiento_ganados: [
        Fabricate(:movimiento_ganado, cant: 30, ganado: ganados.first)
      ])
      # ActiveRecord::Base.logger = Logger.new(STDOUT) if defined?(ActiveRecord::Base)
    end

    after(:each) { Timecop.return }

    let(:inventario_ingr_egr_comprados) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(compra.id) }
    let(:inventario_ingr_egr_vendidos) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(venta.id) }

    it "deberia guardarse en el inventario por predio ingr/egr por ganado" do
      inventario_ingr_egr_comprados.inventario_predio_ingr_egr_ganados
        .find_by_ganado_id(ganados.first.id).cant.should == 60

      inventario_ingr_egr_comprados.inventario_predio_ingr_egr_ganados
        .find_by_ganado_id(ganados.second.id).cant.should == 40
      
      inventario_ingr_egr_vendidos.inventario_predio_ingr_egr_ganados
        .find_by_ganado_id(ganados.first.id).cant.should == 30
    end

    it "deberia guardarse en el inventario por predio ingr/egr" do
      inventario_ingr_egr_comprados.cant.should == 100
      inventario_ingr_egr_comprados.cant_men_a.should == 60
      inventario_ingr_egr_comprados.cant_may_a.should == 40

      inventario_ingr_egr_vendidos.cant.should == 30
      inventario_ingr_egr_vendidos.cant_men_a.should == 30
      inventario_ingr_egr_vendidos.cant_may_a.should == 0
    end

    it "deberia guardarse 1 inventario_predio_ganado por cada ganado" do
      inventario_predio.inventario_predio_ganados.find_all_by_ganado_id(ganados.first.id).count.should == 1
      inventario_predio.inventario_predio_ganados.find_all_by_ganado_id(ganados.second.id).count.should == 1
    end

    it "deberia guardarse en el inventario por predio por ganado" do
      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).saldo_inicial.should == 0
      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).saldo_inicial.should == 0

      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).saldo_parcial.should == 60
      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).saldo_parcial.should == 40

      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 30
      inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 40
    end

    it "deberia habe 1 inventario_predio" do
      InventarioPredio.count.should == 1
    end

    it "deberia guardarse en el inventario por predio" do
      inventario_predio.cant.should == 70
    end

    it "deberia habe 1 inventario" do
      Inventario.count.should == 1
    end

    it "deberia guardarse en el inventario" do
      inventario_predio.inventario.cant.should == 70
    end

    it "deberia guardarse en el inventario por ganado" do
      inventario_predio.inventario.inventario_ganados.find_by_ganado_id(ganados.first.id).cant.should == 30
      inventario_predio.inventario.inventario_ganados.find_by_ganado_id(ganados.second.id).cant.should == 40
    end

    # TODO: probar lo mismo pero despues de movimientos
    context "cuando el usuario crea un recuento despues de haber creado ingresos/egresos" do
      before do
        Timecop.freeze Time.now.advance(days: 1)

        Fabricate(:recuento, predio: san_vicente,
            movimiento_ganados: [
            Fabricate(:movimiento_ganado, cant: 0, ganado: ganados.first),
            Fabricate(:movimiento_ganado, cant: 2, ganado: ganados.second)
          ])
      end

      let(:inventario_ingr_egr_comprados) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(compra.id) }
      let(:inventario_ingr_egr_vendidos) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(venta.id) }

      it "los ingresos/egresos anteriores al recuento no deben aparecer" do
        inventario_predio.inventario_predio_ingr_egrs.count.should == 0
      end

      it "el inventario por predio por ganado deberia ser igual al recuento" do
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).saldo_inicial.should == 0
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).saldo_inicial.should == 0

        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).saldo_pre_rec.should == 30
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).saldo_pre_rec.should == 40

        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).saldo_parcial.should == 0
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).saldo_parcial.should == 2

        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 0
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 2
      end

      it "el inventario por predio debe ser igual al recuento" do
        inventario_predio.saldo_i.should == 0
        inventario_predio.saldo_p.should == 2
        inventario_predio.cant.should == 2
      end
    end

    context "cuando el usuario cierra una gestion, abre una nueva y crea mas ingresos/egresos" do
      before { Timecop.freeze Time.now.advance(months: 1).change(day: 1) }
      let!(:gestion) { Fabricate :gestion,  estado: 'C'}

      before do
        gestion.abrir
        Fabricate(:ingreso, predio: san_vicente, movimientos_tipo: compra,
          movimiento_ganados: [
          Fabricate(:movimiento_ganado, cant: 90, ganado: ganados.first),
          Fabricate(:movimiento_ganado, cant: 200, ganado: ganados.second)
        ])
      end

      let(:inventario_predio) { InventarioPredio.get_inventario(san_vicente.id) }
      let(:inventario_ingr_egr_comprados) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(compra.id) }
      let(:inventario_ingr_egr_vendidos) { inventario_predio.inventario_predio_ingr_egrs.find_by_movimientos_tipo_id(venta.id) }

      it "deberia guardarse en el inventario por predio ingr/egr por ganado de la nueva gestion" do
        inventario_ingr_egr_comprados.inventario_predio_ingr_egr_ganados
          .find_by_ganado_id(ganados.first.id).cant.should == 90

        inventario_ingr_egr_comprados.inventario_predio_ingr_egr_ganados
          .find_by_ganado_id(ganados.second.id).cant.should == 200
      end

      it "deberia guardarse en el inventario por predio ingr/egr" do
        inventario_ingr_egr_comprados.cant.should == 290
      end

      it "deberia guardarse en el inventario por predio por ganado" do
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 120
        inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 240
      end

      it "deberia guardarse en el inventario por predio, sumandose con el saldo de la gestion anterior" do
        inventario_predio.cant.should == 240 + 120
      end

      it "deberia guardarse en el inventario, sumandose con el saldo de la gestion anterior" do
        inventario_predio.inventario.cant.should == 240 + 120
      end

      context "cuando el usuario realiza un recuento en el mismo predio" do
        before do
          Timecop.freeze Time.now.advance(days: 2)

          Fabricate(:recuento, predio: san_vicente,
            movimiento_ganados: [
            Fabricate(:movimiento_ganado, cant: 5, ganado: ganados.first),
            Fabricate(:movimiento_ganado, cant: 10, ganado: ganados.second)
          ])
        end

        let(:inventario_predio) { InventarioPredio.get_inventario(san_vicente.id) }

        it "el inventario por predio por ganado deberia ser igual al recuento" do
          inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 5
          inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 10
        end

        it "el inventario por predio deberia ser igual al recuento" do
          inventario_predio.cant.should == 5 + 10
        end

        it "el inventario deberia ser igual al recuento" do
          inventario_predio.inventario.cant.should == 5 + 10
        end

        context "cuando el usuario crea movimientos desde 'Camba Muerto' hacia 'San Vicente'" do
          before do
            Timecop.freeze Time.now.advance(days: 1)
            # inicializar camba_muerto con un recuento
            Fabricate(:recuento, predio: camba_muerto,
              movimiento_ganados: [
              Fabricate(:movimiento_ganado, cant: 100, ganado: ganados.first),
              Fabricate(:movimiento_ganado, cant: 400, ganado: ganados.second)
            ])

            Timecop.freeze Time.now.advance(days: 1)
            Fabricate(:movimiento, movimientos_tipo: tipo_movimiento, predio: camba_muerto, predio_sec: san_vicente,
              movimiento_ganados: [
              Fabricate(:movimiento_ganado, cant: 5, cant_sec: 4, ganado: ganados.first)
            ])

            Timecop.freeze Time.now.advance(days: 1)
            Fabricate(:movimiento, movimientos_tipo: tipo_movimiento, predio: camba_muerto, predio_sec: san_vicente,
              movimiento_ganados: [
              Fabricate(:movimiento_ganado, cant: 25, cant_sec: 20, ganado: ganados.first)
            ])
          end

          let(:inventario_predio_sec) { InventarioPredio.get_inventario(camba_muerto.id) }

          it "deberia guardarse en el inventario por predio de movimientos por ganado, agrupados segun por 'Camba Muerto'" do
            inventario_predio.inventario_predio_movs.find_by_tipo_and_predio_sec_id("ingr", camba_muerto.id)
              .inventario_predio_mov_ganados.find_by_ganado_id(ganados.first.id).cant.should == 20 + 4

            inventario_predio.inventario_predio_movs.find_by_tipo_and_predio_sec_id("ingr", camba_muerto.id)
              .inventario_predio_mov_ganados.find_by_ganado_id(ganados.first.id).perdidos.should == 1 + 5
          end

          it "deberia guardarse en el inventario por predio de movimientos" do
            inventario_predio.inventario_predio_movs.find_by_tipo_and_predio_sec_id("ingr", camba_muerto.id).cant.should == 20 + 4
            inventario_predio.inventario_predio_movs.find_by_tipo_and_predio_sec_id("ingr", camba_muerto.id).cant_may_a.should == 0
            inventario_predio.inventario_predio_movs.find_by_tipo_and_predio_sec_id("ingr", camba_muerto.id).cant_men_a.should == 20 + 4
          end

          it "el inventario por predio por ganado deberia ser igual al recuento + mas el ingreso desde 'Camba Muerto'" do
            inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 5 + 20 + 4
            inventario_predio.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 10
          end

          it "'Camba Muerto' deberia haber disminuido su inventario en lo que se envió a 'San Vicente'" do
            inventario_predio_sec.inventario_predio_ganados.find_by_ganado_id(ganados.first.id).cant.should == 100 - (5+25)
            inventario_predio_sec.inventario_predio_ganados.find_by_ganado_id(ganados.second.id).cant.should == 400
          end
        end
      end
    end
  end
end