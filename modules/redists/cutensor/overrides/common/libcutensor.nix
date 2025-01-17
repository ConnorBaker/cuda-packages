{
  lib,
  libcublas,
}:
let
  inherit (lib.attrsets) getLib;
in
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs or [ ] ++ [ (getLib libcublas) ];
  meta = prevAttrs.meta or { } // {
    description = "cuTENSOR: A High-Performance CUDA Library For Tensor Primitives";
    homepage = "https://developer.nvidia.com/cutensor";
    maintainers = prevAttrs.meta.maintainers ++ [ lib.maintainers.obsidian-systems-maintenance ];
    license = lib.licenses.unfreeRedistributable // {
      shortName = "cuTENSOR EULA";
      fullName = "cuTENSOR SUPPLEMENT TO SOFTWARE LICENSE AGREEMENT FOR NVIDIA SOFTWARE DEVELOPMENT KITS";
      url = "https://docs.nvidia.com/cuda/cutensor/license.html";
    };
  };
}
