with Files.Environment;
separate (Files_Suite.Startup)
   --  Files sets variables for the programs it starts (and the tests set
   --  them for files), and reads them back through hostkit: a non-ASCII
   --  value must come back as the same UTF-8 -- on Windows the C runtime
   --  passed it on in the ANSI code page, and the wide read gave other
   --  characters back.
   procedure Test_Environment_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Name   : constant String := "FILES_TEST_ENVIRONMENT_ROUND_TRIP";
      Jurgen : constant String := "C:\Users\J" & Character'Val (16#C3#) & Character'Val (16#BC#) & "rgen";
   begin
      Files.Environment.Clear (Name);
      Assert (not Files.Environment.Is_Set (Name), "a cleared variable is not set");
      Files_Suite.Support.Assert_Equal (Files.Environment.Value (Name), "", "a cleared variable reads as nothing");
      Files.Environment.Set (Name, Jurgen);
      Assert (Files.Environment.Is_Set (Name), "a set variable is set");
      Files_Suite.Support.Assert_Equal
        (Files.Environment.Value (Name), Jurgen, "a non-ASCII value reads back as the same UTF-8");
      Files.Environment.Clear (Name);
      Assert (not Files.Environment.Is_Set (Name), "clearing removes it again");
   end Test_Environment_Round_Trip;
