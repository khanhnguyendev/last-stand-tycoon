extends GutTest

func test_median_of_an_odd_count_is_the_middle_value() -> void:
	assert_eq(ReportMath.median([0.9, 0.1, 0.5]), 0.5)
	assert_eq(ReportMath.median([7.0]), 7.0)

func test_median_of_an_even_count_averages_the_two_middle_values() -> void:
	assert_eq(ReportMath.median([4.0, 1.0, 3.0, 2.0]), 2.5)
	assert_eq(ReportMath.median([0.0, 0.0, 0.0, 1.0]), 0.0)

func test_empty_list_gives_zero() -> void:
	assert_eq(ReportMath.median([]), 0.0)
	assert_eq(ReportMath.percentile([], 25.0), 0.0)

func test_percentile_interpolates_linearly() -> void:
	assert_almost_eq(ReportMath.percentile([1.0, 2.0, 3.0, 4.0, 5.0], 25.0), 2.0, 0.0001)
	assert_almost_eq(ReportMath.percentile([0.0, 10.0], 25.0), 2.5, 0.0001)
	assert_almost_eq(ReportMath.percentile([3.0, 1.0, 2.0, 10.0], 25.0), 1.75, 0.0001)
	assert_eq(ReportMath.percentile([3.0, 1.0, 2.0], 0.0), 1.0)
	assert_eq(ReportMath.percentile([3.0, 1.0, 2.0], 100.0), 3.0)
