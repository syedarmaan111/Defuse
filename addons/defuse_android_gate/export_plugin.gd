@tool
extends EditorPlugin

var _export_plugin: AndroidGateExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidGateExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidGateExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_name() -> String:
		return "DefuseAndroidGate"


	func _get_android_manifest_element_contents(
		platform: EditorExportPlatform,
		_debug: bool
	) -> String:
		if not _supports_platform(platform):
			return ""
		return (
			'<uses-permission android:name="android.permission.INTERNET"/>'
			+ '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>'
		)
