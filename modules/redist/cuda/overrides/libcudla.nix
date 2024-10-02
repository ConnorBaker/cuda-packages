{ }:
prevAttrs: {
  autoPatchelfIgnoreMissingDeps = prevAttrs.autoPatchelfIgnoreMissingDeps ++ [
    "libnvdla_runtime.so"
  ];
}
