{ libnvjitlink }:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [ libnvjitlink ];
}
