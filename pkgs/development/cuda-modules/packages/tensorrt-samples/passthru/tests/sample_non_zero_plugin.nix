{
  atLeast,
  finalAttrs,
  lib,
  mkTest,
  sample-data,
  ...
}:
{
  default = mkTest "sample_non_zero_plugin" [
    "sample_non_zero_plugin"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];

  fp16 = mkTest "sample_non_zero_plugin-fp16" [
    "sample_non_zero_plugin"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--fp16"
  ];
}
// lib.optionalAttrs (atLeast "10.0.1") {
  columnOrder = mkTest "sample_non_zero_plugin-columnOrder" [
    "sample_non_zero_plugin"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--columnOrder"
  ];
}
