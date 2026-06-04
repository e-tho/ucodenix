let
  lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
  nodeName = lockFile.nodes.${lockFile.root}.inputs.cpu-microcodes;
in
fetchTree lockFile.nodes.${nodeName}.locked
