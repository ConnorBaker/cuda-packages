{
  atLeast,
  lib,
  mkTest,
  ...
}:
lib.optionalAttrs (atLeast "10.8") {
  default = mkTest "sample_editable_timing_cache" [
    "sample_editable_timing_cache"
  ];
}
