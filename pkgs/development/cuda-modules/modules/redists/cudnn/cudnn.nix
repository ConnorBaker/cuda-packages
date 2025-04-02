{
  lib,
  libcublas,
  zlib,
}:
let
  inherit (lib) maintainers teams;
  inherit (lib.attrsets) getLib;
in
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    # NOTE: Verions of CUDNN after 9.0 no longer depend on libcublas:
    # https://docs.nvidia.com/deeplearning/cudnn/latest/release-notes.html?highlight=cublas#cudnn-9-0-0
    # However, NVIDIA only provides libcublasLT via the libcublas package.
    (getLib libcublas)
    zlib
  ];

  meta = prevAttrs.meta or { } // {
    homepage = "https://developer.nvidia.com/cudnn";
    maintainers =
      prevAttrs.meta.maintainers
      ++ (with maintainers; [
        mdaiter
        samuela
        connorbaker
      ])
      ++ teams.cuda.members;
    license = {
      shortName = "cuDNN EULA";
      fullName = "NVIDIA cuDNN Software License Agreement (EULA)";
      url = "https://docs.nvidia.com/deeplearning/sdk/cudnn-sla/index.html#supplement";
      free = false;
      redistributable = true;
    };
  };
}
