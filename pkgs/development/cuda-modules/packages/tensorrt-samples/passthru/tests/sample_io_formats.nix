{
  backendStdenv,
  lib,
  mkTest,
  sample-data,
  ...
}:
{
  default = mkTest "sample_io_formats" [
    "sample_io_formats"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];
}
# Only Orin has a DLA
// lib.optionalAttrs (lib.elem "8.7" backendStdenv.cudaCapabilities) {
  dla = mkTest "sample_io_formats-dla" [
    "sample_io_formats"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--useDLACore=0"
  ];
}
