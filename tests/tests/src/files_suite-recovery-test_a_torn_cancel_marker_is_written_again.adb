with Files.Protocol_Names;
with Files_Suite.Support.Timing;
separate (Files_Suite.Recovery)
   --  A cancel whose marker write failed part-way (a full disk) left a torn
   --  marker. Every later cancel then found the name taken and the marker
   --  invalid, and refused: the job could never be cancelled. A later cancel
   --  writes it again whole.
   procedure Test_A_Torn_Cancel_Marker_Is_Written_Again (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job : Files.Jobs.Process.Session;
   begin
      Files.Jobs.Process.Reserve (Job);
      Write_Binary_File (Files.Jobs.Process.Path (Job, Files.Protocol_Names.Cancel_File), "ca");
      Files.Jobs.Context.Initialize (Files.Jobs.Process.Path (Job, ""));
      Assert (not Files.Jobs.Context.Cancelled, "a torn marker is no cancel");

      Files.Jobs.Process.Cancel (Job);
      for Attempt in Files_Suite.Support.Timing.Polling loop
         exit when Files.Jobs.Context.Cancelled;
      end loop;
      Assert (Files.Jobs.Context.Cancelled, "a cancel over a torn marker reaches the helper");
      Files.Jobs.Context.Initialize ("");
      Files.Jobs.Process.Reset (Job);
   exception
      when others =>
         Files.Jobs.Context.Initialize ("");
         Files.Jobs.Process.Reset (Job);
         raise;
   end Test_A_Torn_Cancel_Marker_Is_Written_Again;
