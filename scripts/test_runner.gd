extends SceneTree

const TEST_SCRIPT: Script = preload("res://tests/test_core.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var had_failure: bool = false
	var test_instance: Node = Node.new()
	test_instance.set_script(TEST_SCRIPT)
	root.add_child(test_instance)

	var tests: Array[String] = []
	for method: Dictionary in TEST_SCRIPT.get_script_method_list():
		var method_name: String = str(method["name"])
		if method_name.begins_with("test_"):
			tests.append(method_name)
	tests.sort()

	if tests.is_empty():
		push_error("No se encontraron métodos test_* en tests/test_core.gd")
		quit(1)
		return

	print("Ejecutando %d pruebas..." % tests.size())
	for test_name: String in tests:
		print("TEST: %s" % test_name)
		test_instance.call(test_name)

	print("Finalizó la invocación de %d pruebas. Revisa errores/assertions del proceso." % tests.size())
	quit(0)
