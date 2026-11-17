with Ada.Calendar.Formatting;
with GNAT.OS_Lib;
with Files.Protocol_Names;
with Files_Suite.Support.Guards;
separate (Files_Suite.Recovery)
   --  A registered stage with no payload and no marker is left alone while a
   --  Preserve may still be filling it (Test_Unmarked_Stage_Survives_Sweep).
   --  Once it is older than that could take (Unfilled_Stage_Grace), it was
   --  abandoned by a Preserve that stopped before its original moved in: the
   --  sweep removes it and its record. The original, never moved, is kept.
   procedure Test_Abandoned_Unfilled_Stage_Swept (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dest   : constant String := Join (Root, "never-moved.txt");
      Backup : Files.Types.UString;
      Result : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      --  A native backend keeps a replaced original in a private recovery folder.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Write_Binary_File (Dest, "original");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success and then Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "an original is kept for recovery");
      declare
         use type Ada.Calendar.Time;
         Stage : constant String := Ada.Directories.Containing_Directory (To_String (Backup));
         Owner : constant String := Join (Stage, Files.Protocol_Names.Recovery_Owner);
         --  Six hours ago: past the grace a Preserve may still be filling it.
         Earlier : constant Ada.Calendar.Time := Ada.Calendar.Clock - 21_600.0;
         Year  : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day   : Ada.Calendar.Day_Number;
         Hour  : Ada.Calendar.Formatting.Hour_Number;
         Minute : Ada.Calendar.Formatting.Minute_Number;
         Second : Ada.Calendar.Formatting.Second_Number;
         Sub_Second : Ada.Calendar.Formatting.Second_Duration;
      begin
         --  In UTC, as GNAT.OS_Lib.GM_Time_Of reads it.
         Ada.Calendar.Formatting.Split (Earlier, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);
         --  As the stage looks when Preserve stopped between its Register and its move.
         Ada.Directories.Rename (To_String (Backup), Dest);
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Owner,
            GNAT.OS_Lib.GM_Time_Of (Year, Month, Day, Hour, Minute, Second));
         Files.File_System.Sweep_Recovery_Registry;
         Assert (not Ada.Directories.Exists (Stage), "the abandoned, unfilled stage goes");
         Assert (not Files.File_System.Registered_Recovery_Payloads.Contains (Backup),
                 "and its record with it");
         Assert (File_Has_Bytes (Dest, "original"), "the original it never took is kept");
      end;
   end Test_Abandoned_Unfilled_Stage_Swept;
