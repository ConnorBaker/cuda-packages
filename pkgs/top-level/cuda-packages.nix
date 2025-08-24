final: prev:
let
  # NOTE: We avoid path interpolation because it would copy the cudaPackagesPath to a new store output:
  # https://nix.dev/manual/nix/2.28/language/string-interpolation#interpolated-expression
  # Instead, concatenate the path with the string.

  fixups = import ../development/cuda-modules/fixups { inherit (final) lib; };

  # NOTE: Because manifests are used to add redistributables to the package set,
  # we cannot have values depend on the package set itself, or we run into infinite recursion.

  # Since Jetson capabilities are never built by default, we can check if any of them were requested
  # through final.config.cudaCapabilities and use that to determine if we should change some manifest versions.
  # Copied from backendStdenv.
  hasJetsonCudaCapability =
    let
      jetsonCudaCapabilities = final.lib.filter (
        cudaCapability: final._cuda.db.cudaCapabilityToInfo.${cudaCapability}.isJetson
      ) final._cuda.db.allSortedCudaCapabilities;
    in
    final.lib.intersectLists jetsonCudaCapabilities (final.config.cudaCapabilities or [ ]) != [ ];
  importManifest =
    name: version:
    final.lib.importJSON (../development/cuda-modules/manifests + "/${name}/redistrib_${version}.json");
in
{
  # CUDA package sets specify manifests and fixups.
  # cudaPackages_12_2 = final.callPackage ../development/cuda-modules {
  #   inherit fixups;
  #   manifests = mkManifests "12.2.2";
  # };

  _cuda = prev._cuda.extend (
    finalCuda: prevCuda:
    final.lib.recursiveUpdate prevCuda {
      # 12.9 to 13.0 adds support for GCC 15 and Clang 20
      # https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#host-compiler-support-policy
      bootstrapData.nvccCompatibilities."13.0" = {
        clang = {
          maxMajorVersion = "20";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "15";
          minMajorVersion = "6";
        };
      };
    }
  );

  cudaPackages_12_6 = final.callPackage ../development/cuda-modules {
    inherit fixups;
    manifests = final.lib.mapAttrs importManifest {
      cublasmp = "0.4.0";
      cuda = "12.6.3";
      cudnn = "9.8.0";
      cudss = "0.5.0";
      cuquantum = "25.03.0";
      cusolvermp = "0.6.0";
      cusparselt = "0.6.3";
      cutensor = "2.2.0";
      nppplus = "0.10.0";
      nvcomp = "4.2.0.11";
      nvjpeg2000 = "0.8.1";
      nvpl = "25.1.1";
      nvtiff = "0.5.1";
      tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.9.0";
    };
  };

  cudaPackages_12_8 = final.callPackage ../development/cuda-modules {
    inherit fixups;
    manifests = final.lib.mapAttrs importManifest {
      cublasmp = "0.4.0";
      cuda = "12.8.1";
      cudnn = "9.8.0";
      cudss = "0.5.0";
      cuquantum = "25.03.0";
      cusolvermp = "0.6.0";
      cusparselt = "0.7.1";
      cutensor = "2.2.0";
      nppplus = "0.10.0";
      nvcomp = "4.2.0.11";
      nvjpeg2000 = "0.8.1";
      nvpl = "25.1.1";
      nvtiff = "0.5.1";
      tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.9.0";
    };
  };

  cudaPackages_12_9 = final.callPackage ../development/cuda-modules {
    inherit fixups;
    manifests = final.lib.mapAttrs importManifest {
      cublasmp = "0.4.0";
      cuda = "12.9.1";
      cudnn = "9.8.0";
      cudss = "0.5.0";
      cuquantum = "25.03.0";
      cusolvermp = "0.6.0";
      cusparselt = "0.7.1";
      cutensor = "2.2.0";
      nppplus = "0.10.0";
      nvcomp = "4.2.0.11";
      nvjpeg2000 = "0.8.1";
      nvpl = "25.1.1";
      nvtiff = "0.5.1";
      tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.9.0";
    };
  };

  cudaPackages_13_0 = final.callPackage ../development/cuda-modules {
    inherit fixups;
    manifests = final.lib.mapAttrs importManifest {
      cublasmp = "0.4.0";
      cuda = "13.0.0";
      cudnn = "9.8.0";
      cudss = "0.5.0";
      cuquantum = "25.03.0";
      cusolvermp = "0.6.0";
      cusparselt = "0.7.1";
      cutensor = "2.2.0";
      nppplus = "0.10.0";
      nvcomp = "4.2.0.11";
      nvjpeg2000 = "0.8.1";
      nvpl = "25.1.1";
      nvtiff = "0.5.1";
      tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.9.0";
    };
  };

  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  cudaPackages_12 = final.cudaPackages_12_6;

  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;
}
