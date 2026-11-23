package body Files.Recovery_CLI.Testing is

   function Escaped (Text : String) return String renames Files.Recovery_CLI.Escaped;

   function Unescaped (Text : String) return String renames Files.Recovery_CLI.Unescaped;

   function Run
     (Arguments : Files.Types.String_Vectors.Vector;
      Failed    : out Boolean) return Boolean renames Files.Recovery_CLI.Run;

end Files.Recovery_CLI.Testing;
