package body Files.File_System.Trash is

   function Trash_Is_Available return Boolean
     renames Files.File_System.Trash_Is_Available;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Move_To_Trash_Preflight;

   function Trash_Files_Directory return String
     renames Files.File_System.Trash_Files_Directory;

   function Is_Trash_Files_Directory (Path : String) return Boolean
     renames Files.File_System.Is_Trash_Files_Directory;

   function Is_Volume_Trash_Item (Path : String) return Boolean
     renames Files.File_System.Is_Volume_Trash_Item;

   function Trash_Original_Path (Trashed_Path : String) return String
     renames Files.File_System.Trash_Original_Path;

   function Restore_From_Trash
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result
     renames Files.File_System.Restore_From_Trash;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Move_To_Trash;

   function Move_To_Trash
     (Path          : String;
      Trashed_Path  : out Files.Types.UString;
      Recorded_Path : String := "")
      return Mutation_Result
     renames Files.File_System.Move_To_Trash;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
     renames Files.File_System.Delete_Trashed_Item;

end Files.File_System.Trash;
