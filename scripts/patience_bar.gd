extends Control
var ratio:float=1.0
func _ready() -> void:
	custom_minimum_size=Vector2(0,64);mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var colors:Array=[Color("B0D581"),Color("FFD24F"),Color("FF8C68"),Color("B6371C")]
	for i in 4:draw_rect(Rect2(i*size.x/4,39,size.x/4,20),colors[i])
	var x:float=clampf((1-ratio)*size.x,12,size.x-12)
	draw_circle(Vector2(x,15),12,Color("FFDC64"))
	draw_circle(Vector2(x-4,12),1.5,Color("343434"));draw_circle(Vector2(x+4,12),1.5,Color("343434"))
	draw_arc(Vector2(x,15),5,0,PI,12,Color("343434"),1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(x-5,30),Vector2(x+5,30),Vector2(x,37)]),Color("FFDC64"))
