package body Files.Operations.Archives.Writing.Testing is

   function Names_Are_Extractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return Boolean renames Files.Operations.Archives.Writing.Names_Are_Extractable;

   function First_Unextractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return String renames Files.Operations.Archives.Writing.First_Unextractable;

end Files.Operations.Archives.Writing.Testing;
