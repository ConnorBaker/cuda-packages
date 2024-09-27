{
  # Releases for x86_64 can use any CUDA version so long as the major version matches the
  # cuda variant of the package.
  # Other platforms must use the CUDA version specified here.
  # Check for support matrices at versioned documentation URLs like:
  # https://docs.nvidia.com/deeplearning/tensorrt/archives/tensorrt-1010/support-matrix/index.html
  # NOTE: The newest release typically does not have an archive page, and is available at:
  # https://docs.nvidia.com/deeplearning/tensorrt/support-matrix/index.html
  "10.0.1.6" = {
    linux-aarch64 = {
      cudaMajorMinorVersion = "12.4";
      cudnnMajorMinorPatchVersion = "8.9.6";
    };
    linux-sbsa = {
      cudaMajorMinorVersion = "12.4";
      cudnnMajorMinorPatchVersion = "8.9.7";
    };
    linux-x86_64.cudnnMajorMinorPatchVersion = "8.9.7";
  };
  "10.1.0.27" = {
    linux-aarch64 = {
      cudaMajorMinorVersion = "12.4";
      cudnnMajorMinorPatchVersion = "8.9.6";
    };
    linux-sbsa = {
      cudaMajorMinorVersion = "12.4";
      cudnnMajorMinorPatchVersion = "8.9.7";
    };
    linux-x86_64.cudnnMajorMinorPatchVersion = "8.9.7";
  };
  "10.2.0.19" = {
    linux-sbsa = {
      cudaMajorMinorVersion = "12.5";
      cudnnMajorMinorPatchVersion = "8.9.7";
    };
    linux-x86_64.cudnnMajorMinorPatchVersion = "8.9.7";
  };
  "10.3.0.26" = {
    linux-aarch64 = {
      cudaMajorMinorVersion = "12.6";
      cudnnMajorMinorPatchVersion = "8.9.6";
    };
    linux-sbsa = {
      cudaMajorMinorVersion = "12.5";
      cudnnMajorMinorPatchVersion = "8.9.7";
    };
    linux-x86_64.cudnnMajorMinorPatchVersion = "8.9.7";
  };
  "10.4.0.26" = {
    linux-aarch64 = {
      cudaMajorMinorVersion = "12.6";
      cudnnMajorMinorPatchVersion = "8.9.6";
    };
    linux-sbsa = {
      cudaMajorMinorVersion = "12.6";
      cudnnMajorMinorPatchVersion = "8.9.7";
    };
    linux-x86_64.cudnnMajorMinorPatchVersion = "8.9.7";
  };
}
