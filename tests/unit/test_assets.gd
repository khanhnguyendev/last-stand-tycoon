extends GutTest
## S4 spec 5.4: the real project passes the validator. Warnings are printed (the placeholder rule warns until Task 13).

func test_project_assets_valid() -> void:
	var r := AssetValidator.validate_project(self)
	for w in r.warnings:
		gut.p("asset warning: %s" % w)
	assert_eq(r.errors, [], "asset validator errors")
