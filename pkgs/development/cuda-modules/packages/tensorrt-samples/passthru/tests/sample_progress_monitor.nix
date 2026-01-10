{
  backendStdenv,
  lib,
  mkTest,
  sample-data,
  ...
}:
# NOTE: Disabled because it generates way too much output.
lib.optionalAttrs false {
  default = mkTest "sample_progress_monitor" [
    "sample_progress_monitor"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];

  int8 = mkTest "sample_progress_monitor-int8" [
    "sample_progress_monitor"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--int8"
  ];

  fp16 = mkTest "sample_progress_monitor-fp16" [
    "sample_progress_monitor"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--fp16"
  ];
}
# Only Orin has a DLA
// lib.optionalAttrs (false && lib.elem "8.7" backendStdenv.cudaCapabilities) {
  dla = mkTest "sample_progress_monitor-dla" [
    "sample_progress_monitor"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--useDLACore=0"
  ];
}
