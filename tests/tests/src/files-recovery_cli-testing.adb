package body Files.Recovery_CLI.Testing is

   function Escaped (Text : String) return String renames Files.Recovery_CLI.Escaped;

   function Unescaped (Text : String) return String renames Files.Recovery_CLI.Unescaped;

end Files.Recovery_CLI.Testing;
