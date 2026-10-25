separate (Files_Suite.Operations)
   procedure Test_Trash_Deletion_Date (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 0.0)),
         "2024-02-03T00:00:00",
         "trash deletion date formats midnight");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 60.9)),
         "2024-02-03T00:01:00",
         "trash deletion date floors fractional seconds");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Trash_Deletion_Date (Ada.Calendar.Time_Of (2024, 2, 3, 86_399.9)),
         "2024-02-03T23:59:59",
         "trash deletion date does not round up near midnight");
   end Test_Trash_Deletion_Date;
