with Files.File_Identities;
with Files.Job_Context;
separate (Files_Suite.Transfer)
   --  A helper names what it is about to publish or move before it does,
   --  so one stopped between the act and its record still has the entry
   --  found for Undo: by the identity it carries now, and a move only once
   --  its source is gone. An intent that was never carried out is no entry.
   procedure Test_Journal_Intents_Found (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Journal   : constant String := Join (Root, "journal");
      Published : constant String := Join (Root, "published.txt");
      Unmade    : constant String := Join (Root, "never-published.txt");
      Source    : constant String := Join (Root, "moving.txt");
      Moved     : constant String := Join (Root, "moved.txt");
      Kept      : constant String := Join (Root, "kept.txt");
      Entries   : Files.Job_Context.Journal_Entry_Vectors.Vector;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Journal);
      Write_Binary_File (Published, "published bytes");
      Write_Binary_File (Source, "moving bytes");
      Write_Binary_File (Kept, "kept bytes");
      Files.Job_Context.Initialize (Journal);
      --  Published, then stopped before its record.
      Files.Job_Context.Intend_Created
        (Published, "", Files.File_Identities.Token (Published), Files.File_System.Tree_Revision (Published));
      --  Named, then stopped before it was published.
      Files.Job_Context.Intend_Created (Unmade, "", "1:unmade", "revision");
      --  Moved, then stopped before its record.
      Files.Job_Context.Intend_Moved (Moved, Source, Files.File_Identities.Token (Source));
      Ada.Directories.Rename (Source, Moved);
      --  Named, then stopped before it moved: its source is still there.
      Files.Job_Context.Intend_Moved (Join (Root, "not-moved.txt"), Kept, Files.File_Identities.Token (Kept));
      Files.Job_Context.Initialize ("");

      Entries := Files.Job_Context.Read_Created (Journal);
      Assert (Natural (Entries.Length) = 1
              and then To_String (Entries.First_Element.Destination) = Published,
              "a published entry its record never reached is found; one never published is not");
      Entries := Files.Job_Context.Read_Moved (Journal);
      Assert (Natural (Entries.Length) = 1
              and then To_String (Entries.First_Element.Destination) = Moved
              and then To_String (Entries.First_Element.Source) = Source,
              "a move its record never reached is found; one whose source is still there is not");

      --  Recorded too: found once, not twice.
      Files.Job_Context.Initialize (Journal);
      Files.Job_Context.Record_Created (Published);
      Files.Job_Context.Initialize ("");
      Entries := Files.Job_Context.Read_Created (Journal);
      Files_Suite.Support.Assert_Equal (Natural (Entries.Length), 1, "a recorded intent is found once");
   exception
      when others =>
         Files.Job_Context.Initialize ("");
         raise;
   end Test_Journal_Intents_Found;
