{
  backendStdenv,
  lib,
  mkTest,
  sample-data,
  ...
}:
{
  default = mkTest "sample_algorithm_selector" [
    "sample_algorithm_selector"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];

  int8 = mkTest "sample_algorithm_selector-int8" [
    "sample_algorithm_selector"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--int8"
  ];

  fp16 = mkTest "sample_algorithm_selector-fp16" [
    "sample_algorithm_selector"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--fp16"
  ];

  bf16 = mkTest "sample_algorithm_selector-bf16" [
    "sample_algorithm_selector"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--bf16"
  ];
}
# Only Orin has a DLA
// lib.optionalAttrs (lib.elem "8.7" backendStdenv.cudaCapabilities) {
  dla = mkTest "sample_algorithm_selector-dla" [
    "sample_algorithm_selector"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--useDLACore=0"
  ];
}
