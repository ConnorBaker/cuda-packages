{
  callPackage,
  protobuf_21,
}:
callPackage ./generic.nix {
  protobuf = protobuf_21;
  version = "1.12.0";
  hash = "sha256-3awGaKbzvZraGFJWoKIfHDh7qm6gWWfiO3bpGTcMLr0=";
}
