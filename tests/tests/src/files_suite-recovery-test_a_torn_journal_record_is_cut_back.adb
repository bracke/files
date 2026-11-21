with Files_Suite.Support.File_Size_Limits;
with Hostkit.Limits;
separate (Files_Suite.Recovery)
   --  A helper journals what it publishes, one record appended at a time. A
   --  record a full disk cut short stayed in the journal, and the next one
   --  followed it: the reader stops at the first record out of shape, so
   --  every record after the torn one was lost to undo and recovery. A
   --  file-size limit stands in for the full disk.
   procedure Test_A_Torn_Journal_Record_Is_Cut_Back (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Job     : Files.Jobs.Process.Session;
      Full    : Files_Suite.Support.File_Size_Limits.Cap;
      use type Hostkit.Limits.Amount;
      One     : constant String := Join (Root, "one");
      Two     : constant String := Join (Root, [1 .. 200 => 'b']);
      Three   : constant String := Join (Root, "three");
   begin
      Reset_Root;
      Write_Binary_File (One, "1");
      Write_Binary_File (Two, "2");
      Write_Binary_File (Three, "3");
      Files.Jobs.Process.Reserve (Job);
      Files.Jobs.Context.Initialize (Files.Jobs.Process.Path (Job, ""));
      Files.Jobs.Context.Record_Created (One, Join (Root, "source-one"));
      declare
         Journal : constant String := Files.Jobs.Process.Path (Job, "created");
         Before  : constant Hostkit.Limits.Amount := Hostkit.Limits.Amount (Ada.Directories.Size (Journal));
      begin
         if not Files_Suite.Support.File_Size_Limits.Lower (Full, Before + 32) then
            Files.Jobs.Context.Initialize ("");
            Files.Jobs.Process.Reset (Job);
            Files_Suite.Support.Skip ("Test_A_Torn_Journal_Record_Is_Cut_Back", "this host has no file-size limit");
            return;
         end if;
         Files.Jobs.Context.Record_Created (Two, Join (Root, "source-two"));
         Files_Suite.Support.File_Size_Limits.Lift (Full);
         Assert (Hostkit.Limits.Amount (Ada.Directories.Size (Journal)) = Before,
                 "the record the disk cut short is taken back off the journal");
      end;
      Files.Jobs.Context.Record_Created (Three, Join (Root, "source-three"));
      declare
         Entries : constant Files.Jobs.Context.Journal_Entry_Vectors.Vector :=
           Files.Jobs.Context.Read_Created (Files.Jobs.Process.Path (Job, ""));
      begin
         Assert (Natural (Entries.Length) = 2
                 and then To_String (Entries.First_Element.Destination) = One
                 and then To_String (Entries.Last_Element.Destination) = Three,
                 "the record written after it is read:" & Entries.Length'Image & " read");
      end;
      Files.Jobs.Context.Initialize ("");
      Files.Jobs.Process.Reset (Job);
   exception
      when others =>
         Files_Suite.Support.File_Size_Limits.Lift (Full);
         Files.Jobs.Context.Initialize ("");
         Files.Jobs.Process.Reset (Job);
         raise;
   end Test_A_Torn_Journal_Record_Is_Cut_Back;
