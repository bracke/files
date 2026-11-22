package body Files.Leaf_Names.Testing is

   function Cut
     (Head : String;
      Tail : String;
      Room : Natural;
      Unit : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes)
      return String renames Files.Leaf_Names.Cut;

end Files.Leaf_Names.Testing;
