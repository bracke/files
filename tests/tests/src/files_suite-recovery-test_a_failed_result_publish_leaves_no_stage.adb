with Ada.Text_IO;
with Files.IO.Durability.Testing;
separate (Files_Suite.Recovery)
   --  A helper publishes its result through a staged file of a fixed name.
   --  One that could not be put on the device must not stay behind: it
   --  refused every later publish of that result, so the helper's final
   --  answer was lost and the window read its first, empty one.
   procedure Test_A_Failed_Result_Publish_Leaves_No_Stage (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Directory : constant String := Join (Root, "result-publish");
      Staged    : constant String := Join (Directory, Files.Jobs.Process.Staged_Name (Files.Jobs.Process.Result_File));
      Published : constant String := Join (Directory, Files.Jobs.Process.Result_File);
      Refused   : Boolean := False;

      procedure Write_Record (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         String'Output (Stream, "the helper's answer");
      end Write_Record;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Directory);
      Files.IO.Durability.Testing.Fail_Syncs_Ending_With (Files.Jobs.Process.Staged_Name
        (Files.Jobs.Process.Result_File));
      begin
         Files.Jobs.Records.Publish_Result (Directory, Write_Record'Access);
      exception
         when Ada.IO_Exceptions.Use_Error =>
            Refused := True;
      end;
      Files.IO.Durability.Testing.Clear;
      Assert (Refused, "a result that cannot be put on the device is not published");
      Assert (not Ada.Directories.Exists (Staged), "the staged result this publish wrote is removed");
      Files.Jobs.Records.Publish_Result (Directory, Write_Record'Access);
      Assert (Ada.Directories.Exists (Published), "so the next publish of that result goes through");

      --  A staged file whose clean-up the host refused (a scanner holding it,
      --  on Windows) is still in the way of the next publish: that one
      --  removes it first, the job's directory being written by its owner
      --  alone.
      declare
         Leftover : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (Leftover, Ada.Text_IO.Out_File, Staged);
         Ada.Text_IO.Put_Line (Leftover, "left behind");
         Ada.Text_IO.Close (Leftover);
      end;
      Files.Jobs.Records.Publish_Result (Directory, Write_Record'Access);
      Assert (not Ada.Directories.Exists (Staged), "a leftover staged result does not refuse the next publish");
   exception
      when others =>
         Files.IO.Durability.Testing.Clear;
         raise;
   end Test_A_Failed_Result_Publish_Leaves_No_Stage;
