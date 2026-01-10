{
  mkTest,
  sample-data,
  ...
}:
{
  default = mkTest "sample_dynamic_reshape" [
    "sample_dynamic_reshape"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];

  # TODO: Neither the sample data nor the sample sources provide train-images-idx3-ubyte, so we can't run the int8 test.
  # int8 = mkTest "sample_dynamic_reshape-int8" [
  #   "sample_dynamic_reshape"
  #   "--datadir=${sample-data.outPath + "/mnist"}"
  #   "--int8"
  # ];

  fp16 = mkTest "sample_dynamic_reshape-fp16" [
    "sample_dynamic_reshape"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--fp16"
  ];

  bf16 = mkTest "sample_dynamic_reshape-bf16" [
    "sample_dynamic_reshape"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--bf16"
  ];
}
