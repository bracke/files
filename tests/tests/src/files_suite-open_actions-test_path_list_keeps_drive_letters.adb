with Files.Text_Basics;

separate (Files_Suite.Open_Actions)
   --  XDG_DATA_DIRS on Windows is a ';' list of drive paths. Splitting it on
   --  ':' (the POSIX separator) cut "D:\apps\share" into "D" and
   --  "\apps\share", which GNAT then took as absolute on the current drive.
   procedure Test_Path_List_Keeps_Drive_Letters (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Windows : constant Files.Types.String_Vectors.Vector :=
        Files.Text_Basics.Split_Path_List ("D:\apps\share;C:\ProgramData", ';');
      Posix   : constant Files.Types.String_Vectors.Vector :=
        Files.Text_Basics.Split_Path_List ("/usr/local/share::/usr/share", ':');
   begin
      Files_Suite.Support.Assert_Equal (Natural (Windows.Length), 2, "a ';' list of two drive paths is two entries");
      Files_Suite.Support.Assert_Equal
        (To_String (Windows (1)), "D:\apps\share", "the drive letter stays with its path");
      Files_Suite.Support.Assert_Equal (To_String (Windows (2)), "C:\ProgramData", "the second drive path is whole");
      Files_Suite.Support.Assert_Equal (Natural (Posix.Length), 3, "a ':' list keeps its empty entry for the caller");
      Files_Suite.Support.Assert_Equal (To_String (Posix (3)), "/usr/share", "the last POSIX entry is whole");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Text_Basics.Split_Path_List ("", ':').Length), 1, "an empty list is one empty entry");
   end Test_Path_List_Keeps_Drive_Letters;
