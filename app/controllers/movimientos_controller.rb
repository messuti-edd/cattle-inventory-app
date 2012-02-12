class MovimientosController < ApplicationController
  def index
    @movs = Movimiento.order("fecha desc").all()
  end

  def show
  end

  def new
    @movimiento = Movimiento.new
    @movimiento.movimiento_ganados.build

    @type = params[:type]
  end

  def create
    @movimiento = Movimiento.new(params[:movimiento])
    @movimiento.parse_fecha(params[:anio], params[:mes], params[:dia])

    if @movimiento.save()
      redirect_to(@movimiento, :notice => 'Se creo el movimiento.')
    else
      render :action => "new"
    end
  end

  def edit
    @movimiento = Movimiento.find(params[:id])
    @type = @movimiento.type_str

    print @movimiento.movimiento_ganados[0].to_json
  end

  def update
    @movimiento = Movimiento.find(params[:id])

    if @movimiento.update_attributes(params[:movimiento])
      redirect_to @movimiento, :notice => "Se guardó el movimiento"
    else
      render :action => "edit"
    end
  end

  def destroy
    @mov = Movimiento.find(params[:id])
    @mov.destroy

    redirect_to movimientos_url
  end

end
