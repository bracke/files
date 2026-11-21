with Files.Fs_Primitives.Testing;
with Files.Operation_Results;
with Files.Operation_Commands;
with Files_Suite.Support.Guards;
with Files_Suite.Support.Models;
separate (Files_Suite.History)
   --  Undo of a creation the host will not answer for -- a transient EACCES
   --  or EIO as it looks the copy up -- never takes the copy for removed:
   --  either it is removed, or the Undo is still owed. Once the host answers
   --  again, Undo removes it.
   procedure Test_Refused_Lookup_Keeps_Undo_Owed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Made     : constant String := Join (Root, "made.txt");
      Created  : Files.Types.String_Vectors.Vector;
      Step     : Files.Operation_Results.Operation_Result;
      pragma Unreferenced (Step);
   begin
      Reset_Root;
      Write_Binary_File (Made, "made bytes");
      Files.Model.Initialize (Model, Root, Files.File_System.Load_Directory (Root, Settings).Items, Root);
      Files.Operations.Clear_Undo (Model);
      Files.Model.Set_Background_Transfers (Model, False);
      Created.Append (To_Unbounded_String (Made));
      Files.Undo.Recording.Record_Undo
        (Model, Files.Undo.History.Undo_Delete_Created,
         Files_Suite.Support.Models.Undo_Items (Created), Redoable => False);

      Files.Fs_Primitives.Testing.Refuse_Lookups (Made);
      Step := Complete_Operation (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
      Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
      Assert (not Ada.Directories.Exists (Made)
              or else Natural (Files.Model.History.Undo_Entries (Model).Length) = 1,
              "a copy the host would not answer for is removed, or its Undo stays owed -- never forgotten");

      Step := Complete_Operation (Model, Settings, Files.Operation_Commands.Undo_Last (Model, Settings));
      Assert (not Ada.Directories.Exists (Made), "once the host answers, Undo removes the copy");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.History.Undo_Entries (Model).Length), 0, "and the Undo is done");
   exception
      when others =>
         Files.Fs_Primitives.Testing.Stop_Refusing_Lookups;
         raise;
   end Test_Refused_Lookup_Keeps_Undo_Owed;
