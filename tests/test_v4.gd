extends SceneTree
var failures:int=0
var checks:int=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func fresh() -> RefCounted:
	var s=preload("res://scripts/progression_state.gd").new();s.finish_tutorial();s.start_day();s.accept_order();s.setup("bouquet");return s
func _initialize() -> void:
	for center in [Vector2(.5,.43),Vector2(.5,.6),Vector2(.72,.55),Vector2(.3,.3)]:
		var s=fresh()
		for i in 5:s.place("yellow",center)
		check(not s.can_tie(),"untrimmed blocked")
		s.trim([0,1,2,3]);check(not s.can_tie(),"one leaf remaining blocked")
		s.trim([4]);check(s.can_tie(),"overlap ready at "+str(center));check(s.use_tool("wire"),"wire binds")
		check(s.use_tool("ribbon"),"ribbon follows wire")
	var s=fresh()
	for i in 5:s.place("yellow",Vector2(.16+i*.16,.4))
	s.trim([0,1,2,3,4]);check(not s.can_tie(),"spread flowers require gathering")
	for i in 5:s.move_flower(i,Vector2(.65+(i-2)*.035,.6))
	check(s.can_tie(),"offset gathered cluster ready")
	var before:int=s.d.inventory.yellow;s.reset_craft();check(s.d.inventory.yellow==before+5,"reset refunds exactly five")
	print("V4_TEST_RESULT checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
