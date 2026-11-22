package body Files.File_System.Roots is

   function Available_Root_Entries return Root_Entry_Vectors.Vector
     renames Files.File_System.Available_Root_Entries;

   function Root_Label (Path : String; Kind : Root_Kind) return String
     renames Files.File_System.Root_Label;

   function Root_Name (Path : String; Kind : Root_Kind) return String
     renames Files.File_System.Root_Name;

end Files.File_System.Roots;
