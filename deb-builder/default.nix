# The Debian-archive builder largely wraps the redistributable builder.
let
  importJSON = path: builtins.fromJSON (builtins.readFile path);
  manifests = {
    "35.6" = importJSON ./manifests/35.6.json;
  };
in
{
  callPackage,
  dpkg,
  lib,
  fetchurl,
  srcOnly,
  # Use a particular manifest
  manifestMajorMinorVersion,
  # Use a particular package set from the manifest
  manifestPackageSet ? "common",
  # Aggregate all the debs from the selected manifest with a `source` attribute matching this name.
  # Ignored if `null`.
  # Exclusive with `debName`.
  # NOTE: Not called `pname` since NVIDIA debians use a different naming scheme than their redist cousins.
  sourceName ? null,
  # Select exactly one debian archive with a matching name.
  # Ignored if `null`.
  # Exclusive with `sourceName`.
  debName ? null,
  # Additional fixup to apply immediately after unpacking debian archives to `sourceRoot`
  postDebUnpack ? "",
  # The redistributable builder expects src to be null when building on an unsupported platform or unavailable.
  srcIsNull,
  # Fixup function applied to the result of calling the redistributable builder.
  overrideAttrsFn,

  # Args for redist-builder
  libPath,
  packageInfo,
  packageName,
  releaseInfo,
}:
assert sourceName == null -> debName != null;
assert debName == null -> sourceName != null;
assert manifestPackageSet == "common" || manifestPackageSet == "t234";
let
  inherit (lib.attrsets) attrValues filterAttrs mapAttrs;
  inherit (lib.lists) length map unique;

  filteredManifest = filterAttrs (
    debName': attrs:
    if sourceName != null then sourceName == attrs.source or "" else debName == debName'
  ) manifests.${manifestMajorMinorVersion}.${manifestPackageSet};

  debs = mapAttrs (
    _: attrs:
    fetchurl {
      inherit (attrs) sha256;
      url = "https://repo.download.nvidia.com/jetson/${manifestPackageSet}/${attrs.filename}";
    }
  ) filteredManifest;

  version =
    let
      versions = unique (map (attrs: attrs.version) (attrValues filteredManifest));
    in
    assert length versions == 1;
    builtins.elemAt versions 0;

  # Unpack and join the two debian archives
  unpacked = srcOnly {
    __structuredAttrs = true;
    strictDeps = true;

    pname = if sourceName != null then sourceName else debName;
    inherit version;

    srcs = attrValues debs;

    nativeBuildInputs = [ dpkg ];

    # Set sourceRoot when we use a custom unpackPhase
    sourceRoot = "source";

    unpackPhase = ''
      runHook preUnpack
      for src in ''${srcs[@]}; do
        echo "Unpacking debian archive $src to $sourceRoot"
        dpkg-deb -x "$src" "$sourceRoot"
      done

      ${postDebUnpack}

      runHook postUnpack
    '';
  };

  unfixed = callPackage ../redist-builder {
    src = if srcIsNull then null else unpacked;
    inherit
      libPath
      packageInfo
      packageName
      releaseInfo
      ;
  };

  fixed = unfixed.overrideAttrs overrideAttrsFn;
in
fixed
