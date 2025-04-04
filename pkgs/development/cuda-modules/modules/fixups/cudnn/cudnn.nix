{
  lib,
  libcublas,
  zlib,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    # NOTE: Verions of CUDNN after 9.0 no longer depend on libcublas:
    # https://docs.nvidia.com/deeplearning/cudnn/latest/release-notes.html?highlight=cublas#cudnn-9-0-0
    # However, NVIDIA only provides libcublasLT via the libcublas package.
    (lib.getLib libcublas)
    zlib
  ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
      ];
    };
  };

  meta = prevAttrs.meta or { } // {
    homepage = "https://developer.nvidia.com/cudnn";
    maintainers =
      prevAttrs.meta.maintainers
      ++ (with lib.maintainers; [
        mdaiter
        samuela
        connorbaker
      ])
      ++ lib.teams.cuda.members;
    license = {
      shortName = "cuDNN EULA";
      fullName = "NVIDIA cuDNN Software License Agreement (EULA)";
      url = "https://docs.nvidia.com/deeplearning/sdk/cudnn-sla/index.html#supplement";
      free = false;
      redistributable = true;
    };
  };
}
