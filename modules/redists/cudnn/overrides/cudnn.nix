{
  lib,
  libcublas,
  patchelf,
  zlib,
}:
let
  inherit (lib) maintainers;
  inherit (lib.attrsets) getLib;
  inherit (lib.meta) getExe;
  inherit (lib.strings) optionalString versionAtLeast versionOlder;
in
finalAttrs: prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [
    # NOTE: Verions of CUDNN after 9.0 no longer depend on libcublas:
    # https://docs.nvidia.com/deeplearning/cudnn/latest/release-notes.html?highlight=cublas#cudnn-9-0-0
    # However, NVIDIA only provides libcublasLT via the libcublas package.
    (getLib libcublas)
    zlib
  ];

  # Tell autoPatchelf about runtime dependencies. *_infer* libraries only
  # exist in CuDNN 8.
  # NOTE: Versions from CUDNN releases have four components.
  postFixup =
    optionalString
      (versionAtLeast finalAttrs.version "8.0.5.0" && versionOlder finalAttrs.version "9.0.0.0")
      ''
        ${getExe patchelf} "$lib/lib/libcudnn.so" --add-needed libcudnn_cnn_infer.so
        ${getExe patchelf} "$lib/lib/libcudnn_ops_infer.so" --add-needed libcublas.so --add-needed libcublasLt.so
      '';

  meta = prevAttrs.meta // {
    homepage = "https://developer.nvidia.com/cudnn";
    maintainers =
      prevAttrs.meta.maintainers
      ++ (with maintainers; [
        mdaiter
        samuela
        connorbaker
      ]);
    license = {
      shortName = "cuDNN EULA";
      fullName = "NVIDIA cuDNN Software License Agreement (EULA)";
      url = "https://docs.nvidia.com/deeplearning/sdk/cudnn-sla/index.html#supplement";
      free = false;
      redistributable = true;
    };
  };
}
