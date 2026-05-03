$modelname "vetes/darkrp_alarm_clock.mdl"
$body vetes_darkrp_alarm_clock "darkrp_alarm_clock"
$surfaceprop combine_metal
$cdmaterials "entities/vetes/"
$sequence idle "darkrp_alarm_clock" // no animation wanted, so re-using the reference mesh
$collisionmodel "darkrp_alarm_clock_collision" { $concave }